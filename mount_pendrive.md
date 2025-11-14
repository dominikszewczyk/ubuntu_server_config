# Mount pendrive
1. List storages
    ```
    lsblk
    ```
2. Create the directory for pendrive
    ```
    sudo mkdir -p /mnt/usb
    ```
3. Mount
    ```
    sudo mount /dev/sdb# /mnt/usb
    ```
4. Check
    ```
    ls /mnt/usb
    ```
5. Run script
    ```
    cd /mnt/usb
    sudo chmod +x script.sh
    sudo ./script.sh
    ```
6. Unmount
    ```
    sudo umount /mnt/usb
    ```