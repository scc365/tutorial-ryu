# Tutorial: OpenFlow with Ryu

This tutorial looks at creating a simple OpenFlow controller using the Python-based controller framework: Ryu. Specifically, this tutorial covers the creation a layer 2 learning switch controller. Mininet will be used in this tutorial, so if you are not yet familiar with Mininet, please complete the tutorial found [here](https://github.com/scc365/tutorial-mininet).

> ⏰ **Estimated Completion Time**: 1-2 Hours

### Background
OpenFlow is a protocol that defines how the data planes of SDN-enabled network devices communicate with their control planes. To first start using OpenFlow, it is important to understand that is not an implementation or a library, but a _protocol definition_. The means there is no process in a language where you can just import OpenFlow, instead when using OpenFlow you need to either implement the protocol from scratch yourself, or import a library that implements the OpenFlow protocol already. There are many of these, but in this module you will be using Ryu, a Python-based library that implements the protocol.

## Getting Started

To complete this tutorial you should clone this repository onto the provided [virtual machine](https://github.com/scc365/virtual-machine):

```
git clone https://github.com/scc365/tutorial-ryu
cd ./tutorial-ryu
```

Alternatively you can use this as a _Template Repository_ if you wish to have a copy in your own GitHub profile.

> 🔗 You may find these [links](#links) useful throughout this tutorial

## Stages

This tutorial consists of four stages, each of which building on the prior: 

  1. [Running the Controller](#stage-1-running-the-controller)
  2. [Adding Learning Functionality](#stage-2-adding-learning-functionality)
  3. [Using the Flow Table](#stage-3-using-flow-table-modifications)
  4. [Multiple Datapaths](#stage-4-supporting-multiple-datapaths)

## Tasks

There are no specific 'tasks' in this tutorial, instead the tutorial builds on top of the provided Hub controller template. You can consider this tutorial to be a single large task divided into stages.

---

## Stage 1: Running the Controller

This template provides you with an OpenFlow controller (`./controller.py`) that provides functionality to a switch in so that it acts as a basic [Hub](https://en.wikipedia.org/wiki/Ethernet_hub). It is this controller that over the course of the tutorial you will convert into a Layer 2 Learning Switch.

### Topology 
But first, you should get the provided topology up and running. This topology has only a single switch that connects to 4 hosts with varying link constraints. The difference in this topology to the Mininet tutorial topology example is that the controller connects to a _remote controller_ rather than using the default controller provided by Mininet. When the switch starts, it looks for a controller at the given IP:port, and as you will be testing locally, these have been set to `127.0.0.1:6633`. You can run this in Mininet via the `mn` command line tool like so:

```bash
sudo mn --switch ovsk --controller remote --custom ./topology.py --topo tutorialTopology
```

<details>
<summary>Do this with Docker 🐳</summary>
<br>
Build the container image (each time you make a change to the code):
<pre>
docker build --rm -f topology.Dockerfile -t topology:latest .
</pre><br>
Run the container:
<pre>
docker run --rm -it --privileged --network host --name topology topology:latest
</pre><br>
</details>
<br>

The added flag `--controller remote` here is what is telling Mininet to add a remote controller to the topology.

<!-- TODO: Add the topology to the ME repository -->
> 👀 You can see the topology in [`ME`](https://scc365.github.io/me) by importing the example "`Ryu Tutorial`"

### Controller

Now your topology is running, you might notice that there is no connectivity. This is because the switch is looking for a remote controller that isn't there! Now you should create an instance of the Hub controller provided like so:

```bash
ryu-manager ./controller.py
```

<details>
<summary>Do this with Docker 🐳</summary>
<br>
Build the container image (each time you make a change to the code):
<pre>
docker build --rm -f controller.Dockerfile -t controller:latest .
</pre><br>
Run the container:
<pre>
docker run --rm -it --network host --name controller controller:latest
</pre><br>
</details>
<br>

<details>
<summary>Printing debug messages from the controller 🐛</summary>
<br>
The controller has a logger (<code>self.logger</code>) that prints messages to the terminal. Normal <code>self.logger.info("...")</code> messages are printed by default, however, you can use the logger to print debug information too! In the code this looks like: <code>self.logger.debug("...")</code>
<br><br>
To force <code>ryu-manager</code> to show this debug output, you can add the <code>--verbose</code> flag to the command like so:
<pre>
ryu-manager --verbose ./controller.py
</pre>
<br>
Or if you're using Docker, you can add the flag to the <code>Dockerfile</code> like so:
<pre>
CMD [ "--verbose", "./controller.py" ]
</pre>
</details>
<br>

Once running you should see that a datapath connects to the controller. To make sure everything is running as expected, you should test the connectivity as described in the `Testing` tutorial (including testing to see what the link constraints are).

## Stage 2: Adding Learning Functionality

So what you should have running now is a small (star) topology where all the hosts are connected to a single datapath. This datapath is connected to a Ryu-based OpenFlow controller that acts as an Ethernet Hub. 

### Ethernet Hub

Hubs are fairly dumb network devices, simply sending every packet that comes into it out of all its ports (flooding). Because of this, packets that do not need modification to be forwarded can reach their destination, however, if the Hub has many ports, much of the output is wasted.

In some environments, this type of device can be useful primarily due its simplicity and the fact that it does not need to store any state to operate. However, as many packets a Hub forwards are sent on links where the packet will not reach the destination, much of the output is wasted. This can be an issue, particularly in bandwidth constrained networks.

### Provided Controller

> 🧑‍🏫 LU Students: This section will be covered in an interactive manner during the lab sessions!

The controller template provided here allows a connected OpenFlow-enabled device to act as an Ethernet Hub. But it is important to understand how this controller is programmed to be able to build your own.

- The Python class `Controller` extends the Ryu provided class `RyuApp`, so some functionality is handled automatically. For example, when a datapath establishes a connection with the controller, the controller sends a [`Features Request`](https://ryu.readthedocs.io/en/latest/ofproto_v1_3_ref.html#ryu.ofproto.ofproto_v1_3_parser.OFPFeaturesRequest).
- The function `features_handler` is set to be the response handler for the automatically sent Features Request. This is done via the Python function decorator ` @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)`. The function itself does have a use in this Hub controller. It installs a flow table modification with the lowest priority that just sends the packet to the controller, so this flow table entry acts as a flow table miss rule.
- The function `packet_in_handler` is set to be the handler for [`Packet In` events](https://ryu.readthedocs.io/en/latest/ofproto_v1_3_ref.html#ryu.ofproto.ofproto_v1_3_parser.OFPPacketIn). When a packet comes into the controller (as is set to be the default defined in the `features_handler` function), this function handles the event. In this implementation it takes the event, extracts the datapath information, creates an output action that is to output the packet on all ports (flood), and sends this packet out using the action. Perhaps the most important take-away is the following line that specifies the flood action:
  ```Python
  actions = [datapath.ofproto_parser.OFPActionOutput(ofproto.OFPP_FLOOD)]
  ```
- The `add_flow` function is a helper function that takes information commonly used in the creation of flow-mods and converts them into a set of OpenFlow instructions. It then installs the created mod onto the datapath given. This function is used by the `features_handler` to install the flow-table miss mod.


### Layer 2 Learning

> 🧑‍🏫 LU Students: A portion of this section will be covered in a walk-through in the lab session!

To stop Hubs from flooding packets, the device must learn the correct output port for each destination so that it can send packets to it out of the port where the destination is known to be reachable. However, to do this the device must become aware of Layer 2 (OSI Model) fields, thus stopping being a Hub and becoming a Layer 2 Switch.

Below is a short example of the learning process that makes the layer 2 switch:

1. Packet comes into a datapath via port `6` with the source MAC address `43:7F:F8:AC:AE:C0`
2. Datapath checks to see if the packet matches any Flow Table Entries
   - It fails to find a matching entry other than the flow-table miss rule that pushes packets to the controller
3. Packet is sent from the datapath to the controller, encapsulated in a Packet In event
4. Controller receives the packet and its packet in event handler function gets the event
5. Controller extracts the relevant information to learning from the packet's ethernet header and event information, that is the _in_port_, _src_mac_, and _dst_mac_
6. Now the controller "learns" that a host with the source MAC address `43:7F:F8:AC:AE:C0` is reachable via port `6` by storing this information in an in-memory data structure (e.g. a Python dictionary)
7. Next the controller checks if the destination MAC address of the packet has been learned already by performing a lookup on the prior mentioned data structure
   - If so, an action is created telling the packet to be outputted on the port the destination MAC address was associated with in the data structure
   - If not, an action is created telling the packet to be outputted via all ports (flooded)
8. The action is used to create a Packet Output message that is then sent back to the datapath that sent the Packet In event message
9. The datapath then performs the action defined in the message (output to a specific port or flood)

Now, if another packet were to be sent, this time with the _destination_ MAC address `43:7F:F8:AC:AE:C0`, what would happen?

<details>
<summary>Answer 🔍</summary>
As the controller had added an entry to the data strcutrue for the MAC address <code>43:7F:F8:AC:AE:C0</code> that associates with port 6, the controller would tell the datapath to output the packet via port 6 rather than unnecessarily flooding it.
</details>
<br>

### Learning Switch with Ryu

> 🧑‍🏫 LU Students: A portion of this section will be covered in a walk-through in the lab session!

So, as you have access to the hub controller and have it running with the provided topology, you should use this as a base to create your own Layer 2 learning switch.

- For the in-memory data structure, you can use a dictionary (basically `JSON`) to store the MAC address to port mappings.
- You will need to import more of the Ryu package to access the fields in a packet's ethernet header:
  - `from ryu.lib.packet import ethernet`
  - Then a packet's ethernet header can be extracted from the data provided with the Packet In OpenFlow event message: `eth_header = packet.Packet(ev.msg.data).get_protocol(ethernet.ethernet)`
  - Specific fields can then be extracted, for example the destination MAC address: `eth_header.dst`


## Stage 3: Using Flow Table Modifications

With layer 2 learning added to the controller, it is no longer wasting resources by sending packets down routes where they will not reach their destination. However, there is still an efficiency problem with the learning controller described [above](#layer-2-learning)...

This controller requires that the datapath sends all the packets it receives to the controller, regardless of whether a destination MAC has been learned or not. This adds a noticeable latency even on the local testbed created using Mininet. But fear not, OpenFlow has a way to improve this! Much like how the template's `features_handler` installs a flow-mod onto the joining datapath's flow-table that tells it push any packets to the controller, this system can be used to add forwarding logic onto the datapath itself.

### Flow-Table Entries

Each OpenFlow-enabled device has a flow-table(s) that contains flow-table entries (flow-mods), but what exactly is a flow-table entry?

Each entry contains 6 fields:
 - **Match**: This is a selection of packet header values. If a packet header contains all the value specified in a match, then the entry will apply to the packet. All header values that are _not_ specified in the match are wildcarded.
 For example: if a match were to exist that looked like so `eth_dst=AC:C7:86:F3:1D:18, eth_type=0x0800, ipv4_dst=10.1.1.7`, then a packet would require both of those fields to be alike for the entry to apply to it.
 Matches must be built from layer 2 up such that to use `IPv4` fields, the `eth_type` must be set to `IPv4`, and to use `TCP` fields the `ip_proto` must be set to `TCP` and so on...
 - **Priority**: When checking if a packet matches any flow-table entries, the entries are checked against the packet's headers from the highest priority entries to the lowest.
 For example: if an entry with priority `18` told the datapath to output via port 7, another matching entry with priority `6` would have no effect.
 - **Counters**: These are the metrics associated with the entry. This records values such as how many packets have matched with the entry.
 - **Instructions**: This is a set of OpenFlow actions to apply to packets that have matched the entry such as the Packet Output action.
 - **Timeouts**: As flow-table memory is not infinite, entries are typically created with timeouts. An idle timeout that will remove the entry should no packets match it in the given time, and a hard timeout to remove the entry after the given time, regardless of packets matching it.
 - **Cookie**: This is a sort of identifier for the entry that the controller can specify.

### Side Note: Debugging with OpenFlow

The OpenFlow controller and the software bridges in the Mininet topology should be communicating via the loopback (`lo`) interface on port `6633` (or `6653`). Therefore, if you wish to inspect the communication between these entities, you can monitor the `lo` interface via `wireshark` or `tshark`. See more about this in the [testing guide](https://github.com/scc365/guide-network-testing)!

### Using Flow-Mods

In your layer 2 learning switch, use flow-mods in such a way that packets that have been added to the mappings data structure can be forwarded without being sent to the controller each time. Packets with destination MAC addresses that have not been added should still be sent to the controller so that the information from it can be added if necessary.

The `add_flow` function provided with the template should be of use here. However, you could extend it so that timeout values could be passed via its parameters. [This part](https://ryu.readthedocs.io/en/latest/ofproto_v1_3_ref.html?highlight=OFPFlowMod#ryu.ofproto.ofproto_v1_3_parser.OFPFlowMod) of the Ryu documentation should be useful.

## Stage 4: Supporting Multiple Datapaths

One of the best uses of SDN is having multiple datapaths be associated with a given controller. If numerous OpenFlow-enabled devices need to implement the same logic (or devices need to easily share state), having them use the same controller instance can be beneficial.

The layer 2 learning switch so far can only support a single datapath connecting to it because its state (the mappings of MAC addresses to ports) has no concept of datapaths, instead all state would be applied to all datapaths.

> Or you may have implemented multiple datapath support already? If so, go you!! 🎉

Luckily, when events are sent to the controller they contain a reference to the datapath that sent the message. This datapath construct contains a unique ID (`dpid`). So to add support for multiple datapaths to your controller, you need to make sure each datapath can access its own separate state. This can be done in the Ryu controller by nesting the dictionary that holds the state into a dictionary of datapath IDs.

Before you go and add this support though, you should make sure that you are running the topology that has 2 switches!

### 2 Switch Topology

The topology provided contains 2 topologies:
1. The one you have used so far with 1 switch: `tutorialTopology`
2. A similar topology but with 2 switches: `tutorialTopologyAdvanced`

You can switch to the other topology like so:

```bash
sudo mn --switch ovsk --controller remote --custom ./topology.py --topo tutorialTopologyAdvanced
```

Where the only change is the `--topo` flag in the `mn` command.

<details>
<summary>Do this with Docker 🐳</summary>
<br>
Change the <code>CMD</code> line in the topology <code>Dockerfile</code> to add the updated <code>--topo</code> flag:
<pre>
CMD [ "--switch ovsk --controller remote --custom /topology/topology.py --topo tutorialTopologyAdvanced" ]
</pre><br>
Build the container image (each time you make a change to the code):
<pre>
docker build --rm -f topology.Dockerfile -t topology:latest .
</pre><br>
Run the container:
<pre>
docker run --rm -it --privileged --network host --name topology topology:latest
</pre><br>
</details>
<br>

## Solution

<!-- TODO: Add link to solution repository -->
A solution for this tutorial will be available [here](https://github.com/scc365/tutorial-solution-ryu) on GitHub (in week 13). However, this tutorial is not assessed and is designed to help you get familiar with Ryu, so make sure you make your own attempt before looking at the solution.

## Links
 - Network Testing Guide: [SCC365 GitHub](https://github.com/scc365/guide-network-testing)
 - The OpenFlow 1.3.5 Protocol Definition: [OpenNetworking](https://opennetworking.org/wp-content/uploads/2014/10/openflow-switch-v1.3.5.pdf)
 - The Ryu OpenFlow Controller Framework: [Ryu](https://ryu-sdn.org)
 - The Ryu Library Documentation: [Read The Docs](https://ryu.readthedocs.io/en/latest/)
 - Ethernet Hub Information: [Wiki](https://en.wikipedia.org/wiki/Ethernet_hub)
