# TDR_Alert_Runspaces
## .SYNOPSIS
Small utility to detect specific event ID in all active virtual machines in Citrix XenDesktop environment. Utility leverages multithreaded runspaces to minimize execution time.

## .DESCRIPTION
Citrix XenDesktop is able to leverage NVIDIA GRID technology to boost graphics and improve overall end-user experience. NVIDIA GRID technology on VMWare ESXI hypervisor has been known to experience system faults which can lead to hypervisors experiencing purple-screen-of-death. 

Virtual machines being hosted on hypervisors running NVIDIA Grid require a graphics driver in order to fully utilize this NVIDIA hardware. The graphics driver in the guest VM generates a system event ID = 4101 warning of hardware failure. Unfortunately, if a hypervisor host crashes, all of the virtual machines on the host fail as well. The main pain point here is that the Citrix Farm will not register these sessions as 'terminated' meaning users will not be able to start a fresh session since the Broker still thinks there is an 'active' session on the backend.

From a business continuity standpoint, we can leverage the event ID 4101 to predict an impeding failure of a host. The utility scans all virtual machines in the Citrix environment for any 4101 errors generated in the past 20 minutes. 

If an event is detected, the following will occur:
  1. All time stamps will be captured in a log file.
  2. List of impacted virtual machines along with the current user (if any) and hypervisor host name are neatly formatted using CSS
  3. Email containing the information from steps 1 + 2 above is sent out to the Helpdesk and any other necessary recipients.
  4. Helpdesk will reach out to listed users in the email to notify them and advise them to save their work and terminate their sessions. Users will be able to log back in immediately so they are given a new virtual machine on a different hypervisor host.
 
 Please note, while the helpdesk is coordinating logoffs with users, the administration team is powering down VMs on the impacted hypervisor host and prepping the host for maintenance work.
 
 Below is an exmaple of the correspondance data:
 
 Machine_Name | Current_User | ESXi_Host
------------ | ------------- | -------------
VirtualMachine_132 | Domain\Username_01 | Hypervisor_234
VirtualMachine_043 | Domain\Username_04 | Hypervisor_234
VirtualMachine_031 | Domain\Username_06 | Hypervisor_234

## .ACCOMPLISHMENTS/WHAT I LEARNED
Although this script was intended to benefit the environment from a business continuty point, the technical benefit of this was learning to optimize powershell scripts using runspaces.

Native powershell runspaces for threading tasks can be cumbersome and not provide streamline methods of customization. PoshRSJOB is a wrapper to the native runspaces framework and provides an intutive method of tweaking attributes such as the timeout limit for each thread, throttle number of parallel threads, and easily pass in functions/modules/snapins to each runspace that gets created.

Without runspaces, scanning of 1600 virtual machines by iterating through the list in a linear fashion resulted in 15 minutes of execution time. 

Implementing the utlility using runspaces brought the total run time to less than 10 seconds. Server resources are not  heavily impacted as well. Hosting server had 4 CPU cores + 8 GB of RAM. Resource utilization barely increased at runtime.

## .AREAS OF IMPROVEMENT
Areas of improvement would be dynamically passing an event ID in to each runspace. This would help anyone running the script dynamically input their targetted iD. Additionally, packing this script and adding parameter input would allow for anyone to pass parameters via terminal.

## .NOTES
Script was created using Powershell 5.1. 

PoshRSJob and Citrix Broker SDK are required. Script can be leveraged for non-citrix managed virtual machines by simple providing computer names via another source.
