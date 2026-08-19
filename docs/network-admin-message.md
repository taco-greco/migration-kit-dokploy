Hi [name],

Following up on the self-hosting project — it went well enough on the test PC that we've now bought a real server for it (a Dell PowerEdge R630) and I'm setting up a second mini PC to test the migration process before moving everything to the real box.

Like you did for the first test PC, could you give this new mini PC a fixed IP too (DHCP reservation or static, whatever's easiest on your end)? Its current MAC address is [MAC — get with `ip link show` on the mini PC] and current IP is [IP — get with `hostname -I`].

Also, when you get a chance, could we grab 15-20 minutes for you to show me how you did the reservation for the first PC? I'll need to do the same thing again for the real server once it's racked, and for a domain name we're planning to point at it internally, so it'd help to actually see the process rather than guess at it. Also curious how often IPs rotate on our network normally (in case a reservation ever needs renewing).

Let me know what works for your schedule.

Thanks,
[Tasos]
