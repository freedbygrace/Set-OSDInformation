# Set-OSDInformation
Works independently or along with the Set-OSDTime script to retrieve built-in and custom task sequence variables marked with a prefix. The values from those variables can then be optionally recorded to the registry, and additional WMI. The WMI class properties will be tied to the registry values. This is the same functionality seen from the ZTITatoo script from MDT, but more flexible and complete. The WMI class will also be set with auto recovery using MofComp in the event of WMI repository rebuilds. 

Some default task sequence variables will always get recorded, but anything that you prefix with the configurable "OSDVariablePrefix" parameter, allows you to create custom task sequence variables and this script will detect those variables and add them to the registry or WMI. See the script notes at the top of the script for more information. This script will also make a best attempt at determing the data types based on variable names and value type combinations so that when the data gets recorded into WMI, you retain the ability to sort the data based on date, true/false, numerical values, etc. If all the data went in as strings, dates for example would only be cosmetic, so you could not sort oldest to newest.

Have Fun!

![image](https://user-images.githubusercontent.com/13382869/83370904-b2487d00-a38e-11ea-858f-bc7e5f27474e.png)
