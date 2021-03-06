#!/bin/bash

#Variable Initialisation-----------
Therm1MacAdress="A4 C1 38 92 34 F6"
Therm2MacAdress="A4 C1 38 40 2D 58"
Therm3MacAdress="A4 C1 38 E9 B7 AA"
Therm1FileName="Room.txt"
Therm2FileName="LVRoom.txt"
Therm3FileName="BathRoom.txt"
Room1Name="Chambre"
Room2Name="Salon"
Room3Name="SDB"
ScanDuration=45
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
        dt=$(date '+%d/%m/%Y %H:%M:%S');
        echo $dt
        print "Therm1MacAdress='$Therm1MacAdress'"
        print "Therm2MacAdress='$Therm2MacAdress'"
        print "Therm3MacAdress='$Therm3MacAdress'"
        print "Therm1FileName='$Therm1FileName'"
        print "Therm2FileName='$Therm2FileName'"
        print "Therm3FileName='$Therm3FileName'"
        print "Room1Name='$Room1Name'"
        print "Room2Name='$Room2Name'"
        print "Room3Name='$Room3Name'"
}

#print output files
print_output_files(){
        print "---Therm1FileName---"
        cat_debug $Therm1FileName
        print "---Therm2FileName---"
        cat_debug $Therm2FileName
        print "---Therm3FileName---"
        cat_debug $Therm3FileName
}

#deleting potential old files...
clear_files (){
        print "Deleting potential old files..."
        rm -rf raw.txt result.txt results.txt output.txt output2.txt log.txt $Therm1FileName $Therm2FileName $Therm3FileName
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
        grep "$Therm3MacAdress" results.txt > $Therm3FileName
        rm -rf results.txt
}

#Update room
update_room(){
        #ThermFileName $1
        #RoomName $2
        #IDX $3

        TEMPRoom=0
        HMDTRoom=0

        FirstLineRoom=$(head -n 1 $1)
        TempRoom=${FirstLineRoom:72:5} #Looking for 2 int16
        printf -v TempRoom '%s' $TempRoom #Suppressing extra space
        HumidityRoom=${FirstLineRoom:78:2}
        TEMPRoomHexa=$(( 16#$TempRoom))
        TEMPRoom=$(echo "scale = 1; $TEMPRoomHexa / 10" | bc)
        HMDTRoom=$(( 16#$HumidityRoom))

        print "Temperature $2: $TEMPRoom"
        print "Humidity $2: $HMDTRoom"
        print "Querry $2: http://192.168.1.100:8080/json.htm?type=command&param=udevice&idx=$3&nvalue=0&svalue=$TEMPRoom;$HMDTRoom;0"

        if awk "BEGIN {exit ($TEMPRoom == 0)}"; then
                curl --silent --output /dev/null "http://192.168.1.100:8080/json.htm?type=command&param=udevice&idx=$3&nvalue=0&svalue=$TEMPRoom;$HMDTRoom;0"
                return 0
        else
                print "No temperature data for $2. No update send."
                return 222
        fi
}


#deleting trash files
deleting_trash_files(){
        rm -rf $Therm1FileName $Therm2FileName $Therm3FileName
}

update_rooms() {

        RES=0

        update_room "$Therm1FileName" "$Room1Name" "1" #BedRoom
        RES=$((RES+$?))
        update_room "$Therm2FileName" "$Room2Name" "2" #LivingRoom
        RES=$((RES+$?))
        update_room "$Therm3FileName" "$Room3Name" "5" #Bathroom
        RES=$((RES+$?))

        print "RES=$RES"

        if [ $RES -eq 666 ]; then
                print "Error, rebooting..."
                date > rebooted.txt
                print "Had to reboot cause RES=$RES" >> rebooted.txt
                #shutdown -r now
        fi
}

print_initial_values
clear_files
rebooting_bluetooth
scanning
parsing
print_output_files
update_rooms
deleting_trash_files
