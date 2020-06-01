# Set-OSDInformation
Works independently or along with the Set-OSDTime script to retrieve built-in and custom task sequence variables marked with a prefix. The values from those variables can then be optionally recorded to the registry, and additionally WMI. This is some of the same functionality seen from the ZTITatoo.wsf script from MDT, but more flexible and complete. The newly WMI class will also be set with auto recovery using MofComp in the event of WMI repository rebuilds. This script will also make a best attempt at determing the data types based on variable names and value type combinations so that when the data gets recorded into WMI, you retain the ability to sort the data based on date, true/false, numerical values, etc. If all the data went in as strings, dates for example would only be cosmetic, so you could not sort oldest to newest.

Note: The MOF file for the WMI class will be created on the fly and imported using MOFComp.exe

Note: Alot of attention was put into the logging. Please check it for errors and more detailed information when testing in your respective environments!

Have Fun!

![image](https://user-images.githubusercontent.com/13382869/83370904-b2487d00-a38e-11ea-858f-bc7e5f27474e.png)
