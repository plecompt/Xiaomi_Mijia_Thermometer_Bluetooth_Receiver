
#!/bin/bash

#Variable Initialisation-----------
Therm1MacAdress="A4 C1 38 92 34 F6"
Therm2MacAdress="A4 C1 38 40 2D 58"
Therm1FileName="Room.txt"
Therm2FileName="LVRoom.txt"
Room1Name="Chambre"
Room2Name="Salon"
ScanDuration=30
Debug=false
#----------------------------------

#Checking for debug mode
if [ $# -eq 1 ]
  then
    if [ $1 = "-debug" ]
        then
        Debug=true
    fi
fi

print () {
        if $Debug; then
                echo $1
        fi
}

cat_debug () {
        if $Debug; then
                cat $1
        fi
}

#print initial values
print_initial_values(){
        print "Therm1MacAdress='$Therm1MacAdress'"
        print "Therm2MacAdress='$Therm2MacAdress'"
        print "Therm1FileName='$Therm1FileName'"
        print "Therm2FileName='$Therm2FileName'"
        print "Room1Name='$Room1Name'"
        print "Room2FileName='$Room2Name'"
}

#print output files
print_output_files(){
        print "---$Therm1FileName---"
        cat_debug $Therm1FileName
        print "---$Therm2FileName---"
        cat_debug $Therm2FileName
}

#deleting potential old files...
clear_files (){
        print "Deleting potential old files..."
        rm -rf raw.txt result.txt results.txt output.txt output2.txt $Therm1FileName $Therm2FileName
}

#rebooting the bluetooth
rebooting_bluetooth (){
        hciconfig hci0 down
        print "Shuting down Bluetooth Peripheral"
        sleep 2
        hciconfig hci0 up
        print "Waking up Bluetooth Peripheral"
        sleep 2
}

#scanning LEBluetooth devices
scanning(){
        print "Scanning for Low Energy Bluetooth devices for $ScanDuration seconds"
        timeout $ScanDuration hcidump --raw --snap-len=32 > raw.txt &
        timeout $ScanDuration hcitool lescan > /dev/null &
        wait
}

#Parsing results
parsing(){
        #deleting '\n'
        tr -d '\n' < raw.txt > output.txt
        #deleting raw file
        rm -rf raw.txt
        #replacing '>' by '\n'
        tr '>' '\n' < output.txt > output2.txt
        #deleting output.txt
        rm -rf output.txt
        #deleting duplicates spaces
        awk '{$1=$1} 1' output2.txt > results.txt
        #deleting output2.txt
        rm -rf output2.txt
        #keeping announcement packet
        grep "$Therm1MacAdress" results.txt > $Therm1FileName
        grep "$Therm2MacAdress" results.txt > $Therm2FileName
        rm -rf results.txt
}

#update room1
update_room1(){
        TEMPRoom=0
        HMDTRoom=0

        FirstLineRoom=$(head -n 1 $Therm1FileName)
        Temp=${FirstLineRoom:75:2}
        Humidity=${FirstLineRoom:78:2}
        TEMPRoomHexa=$(( 16#$Temp))
        TEMPRoom=$(echo "scale = 1; $TEMPRoomHexa / 10" | bc)
        HMDTRoom=$(( 16#$Humidity))

        print "Temperature $Room1Name: $TEMPRoom"
        print "Humidity $Room1Name: $HMDTRoom"

        if awk "BEGIN {exit ($TEMPRoom == 0)}"; then
                curl --silent --output /dev/null "http://192.168.1.68:8080/json.htm?type=command&param=udevice&idx=1&nvalue=0&svalue=$TEMPRoom;$HMDTRoom;0"
        else
                print "No temperature data for $Room1Name. No update send."
        fi
}

#update room2
update_room2(){
        TEMPLVRoom=0
        HMDTLVRoom=0

        FirstLineLVRoom=$(head -n 1 $Therm2FileName)
        TempLVRoom=${FirstLineLVRoom:75:2}
        HumidityLVRoom=${FirstLineLVRoom:78:2}
        TEMPLVRoomHexa=$(( 16#$TempLVRoom))
        TEMPLVRoom=$(echo "scale = 1; $TEMPLVRoomHexa / 10" | bc)
        HMDTLVRoom=$(( 16#$HumidityLVRoom))

        print "Temperature $Room2Name: $TEMPLVRoom"
        print "Humidity $Room2Name: $HMDTLVRoom"

        if awk "BEGIN {exit ($TEMPLVRoom == 0)}"; then
                curl --silent --output /dev/null "http://192.168.1.68:8080/json.htm?type=command&param=udevice&idx=2&nvalue=0&svalue=$TEMPLVRoom;$HMDTLVRoom;0"
        else
                print "No temperature data for $Room2Name. No update send."
        fi
}

#deleting trash files
deleting_trash_files(){
        rm -rf $Therm1FileName $Therm2FileName
}


print_initial_values
clear_files
rebooting_bluetooth
scanning
parsing
print_output_files
update_room1
update_room2
deleting_trash_files
