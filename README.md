# Set-OSDInformation
Works independently or along with the Set-OSDTime script to retrieve built-in and custom task sequence variables marked with a prefix. The values from those variables can then be optionally recorded to the registry, and additional WMI. The WMI class properties will be tied to the registry values. This is the same functionality seen from the ZTITatoo script from MDT, but more flexible and complete. The WMI class will also be set with auto recovery using MofComp in the event of WMI repository rebuilds. 

![image](https://user-images.githubusercontent.com/13382869/83370824-7c0afd80-a38e-11ea-9881-218908e56ca4.png)
