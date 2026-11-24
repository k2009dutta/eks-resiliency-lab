# EKS Resiliency Lab

This lab examines how a two-replica NGINX service on Amazon EKS behaves when a pod is replaced, a worker disappears, and scheduling constraints limit placement. The November 23, 2026 capture shows that Kubernetes restored workload capacity after worker loss. The HTTP monitor also recorded failed probes during the overall capture.

## Architecture

Terraform provisions EKS 1.33 in `ap-south-1`, with one managed `t3.medium` worker in each of two private subnets in different Availability Zones. A single NAT gateway provides outbound access. The Kubernetes manifest defines two NGINX replicas, HTTP readiness and liveness probes, and a ClusterIP Service. The capture includes a separate curl monitor pod.

[Terraform VPC](terraform/main.tf) · [EKS configuration](terraform/eks.tf) · [Workload manifest](kubernetes/resilience-app.yaml)

## What the evidence shows

| Scenario | Observed behavior | Evidence |
| --- | --- | --- |
| Pod replacement | The ReplicaSet created a new pod after an earlier pod stopped. The new container started on the same worker. | [Pod lifecycle events](evidence/events.txt#L36-L40) |
| Worker loss | The original worker became `NotReady` and was removed after the cloud provider reported it missing. A replacement app pod started on the surviving worker. A new worker registered and became ready. | [Node and pod events](evidence/events.txt#L53-L70), [final node snapshot](evidence/nodes.txt) |
| Scheduling under constrained capacity | A pod failed scheduling when one worker was unschedulable and the other failed the topology spread constraint. The final deployment uses `ScheduleAnyway`, and the final pod snapshot shows both ready app replicas on one worker. | [Scheduler event](evidence/events.txt#L101), [deployment snapshot](evidence/deployment.yaml#L81-L100), [final pod snapshot](evidence/pods.txt) |

### HTTP probe results

The [longer HTTP capture](evidence/http-monitor.log) spans 14:35:56–15:00:08 UTC. Of **1,420 recorded probes**, **1,393 returned HTTP 200 (98.1%)** and **27 recorded `000`**, meaning the client received no HTTP status. The longest streak was 18 consecutive failed probes. The next HTTP 200 came roughly 36 seconds after the first failed probe in that streak, using the probe timestamps in column two.

[First failure window](evidence/http-monitor.log#L230-L254) · [Second failure window](evidence/http-monitor.log#L832-L838)

Verify the counts from the repository root:

```sh
awk '{ count[$3]++ } END { for (code in count) print code, count[code] }' evidence/http-monitor.log | sort
```

The event export uses relative ages and the probe log uses UTC timestamps. The artifacts lack a timestamped record of each test action, so the probe failures cannot be conclusively assigned to individual experiments. The 98.1% figure describes this capture from one in-cluster client. The lab scope covers individual workers and an internal Service. A full Availability Zone outage and the public client path would require separate tests.

## Architecture trade-off

`ScheduleAnyway` lets the scheduler prefer spreading replicas across zones while still allowing both to run on an eligible worker during reduced capacity. The final colocated pods demonstrate the trade-off: both replicas can be ready while sharing one worker failure domain. The single NAT gateway also creates a shared dependency for outbound access.

For a follow-up run, record the UTC time of each test action alongside node conditions, ready Service endpoints, and HTTP probe results. Measure time to first successful probe and time to restore both ready endpoints separately.
