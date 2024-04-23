## Run mc-server with plugins on k8s
Host your Minecraft server with plugins on Kubernetes! Using Kubernetes (k8s), you can easily manage your server's resources with pods and containers. This script and explanation make it beginner-friendly for those eager to explore Kubernetes. Let's get started

#### Function
 minecraft-server container is configured to run the `Minecraft server` using the `itzg/minecraft-server image`. It accepts various environment variables to customize the server settings, mounts persistent storage for server data, and exposes ports for gameplay and remote administration.


#### Environment Variables
* `EULA:` It says `"true"` to acccept mc rules automatically.
* `DIFFICULTY`: It makes the game easy, normal, or hard.

* `RCON_PASSWORD:` It's the secret password to control the server remotely.
  
* `TYPE:` Decides which version of the server software to use. 
  - Here, it's using a faster version called Spigot.
* `VERSION:` Specifies which version of Mintheecraft the server will run.
* `FORCE_REDOWNLOAD:` Makes sure the server downloads everything it needs again.
* `ENABLE_UPDATE:` Lets the server automatically get the newest updates.
* `MODPACK:` Specifies a collection of mods to use in the game.
* `SPIGOT_DOWNLOAD_URL:` The link where the server software can be downloaded from.
* `BUILD_SPIGOT_FROM_SOURCE:` Tells the server to build itself from the original code.
`FORCE_WORLD_COPY:` Decides if it should copy the game world again.
* `WORLD:` Specifies which world to play in.

if you wanna make further changes there's [Minecraft server dockor help](https://docker-minecraft-server.readthedocs.io/en/latest/) check it out and make sure you read everything before applying it.


##### Uploading world & mod/plugins pack using cloud zip file
If you wanna upload the world you previously had or modpack/plugins pack you previous have. you can either use dropbox or other cloud based plattform. You need to create a zip file and upload it and copy the link and take the URL (link) and put it in the `value` in `WORLD`. It's important to turn the inside file to zip file and not the outside file to zip file.

```yaml
- name: WORLD
  value: "URL=1"
```
```yaml
- name: MODPACK
  value: "URL=1"
```
##### Avoiding corrupted backup world file
* Change the enviverment variable `FORCE_WORLD COPY` to `"true"` 
Once it has been restore you need to set `FORCE_WORLD_COPY` to `"false"`. 
(Do so the backup file doesn't become corrupt when saving and restoring)

```yaml
- name: FORCE_WORLD_COPY
  value: "true" 
```

##### Creating backup and restoring backup
There's a simple process to restoring and backing up the minecraft-server without using `cronjob`. There's different way of doing it. But after days of research this is the best way:

##### Creating an initContainers with another image that runs backup:
Thanks to our amaizng image `itzg/mc-backup` the minecraft-server has it own restoring and backing up process. Which mean we don't have to make our own. Make sure you added PV and PVC for `minecraft-backup` and `minecraft-data`.

```yaml
    spec:
      initContainers:
      - name: restore
        image: itzg/mc-backup
        volumeMounts:
        - name: minecraft-data
          mountPath: /data
        - name: minecraft-backup
          mountPath: /backups
        command: 
        - restore-tar-backup
      containers:
      - name: mc-backup
        image: itzg/mc-backup
        env:
        - name: BACKUP_INTERVAL
          value: "24h"  # Adjust backup interval as needed
        # Add other environment variables for backup configuration
        - name: BACKUP_NAME
          value: backup
        - name: PAUSE_IF_NO_PLAYER
          value: "true"
        - name: RCON_PASSWORD
          value: # your password
        volumeMounts:
        - name: minecraft-data
          mountPath: /data
          readOnly: true
        - name: minecraft-backup
          mountPath: /backups
        # Add other volume mounts as necessary
```
There's risk with this backup script because it's storing it in the pod / cluster so if the pod goes down then you'll also lose your backup. That's why it's important to have either cloud backup or local backup. Please note that's important!

##### Copying the backup file manually
If you wanna run backup manually using command, you can do that. First of you wanna run command `PWD` to know what file you're using. Then try to locate you backup file using same method.

```bash
kubectl cp YOUR POD-NAME:/data /path/to/your/backup
```
An good exampel:
```bash
kubectl cp minecraft-server-xxxx-xxxx:/data /home/user/backup
```
After running the one line command you should see on your backup.file that it should contain everything that it's inside the root file.

##### Checking/Testing commands for k8s (beginner-friendly)
- `kubectl get pod`: Retrieves information about pods in the cluster.
- `kubectl apply -f (file)`: Applies the configuration from the specified file to create or update Kubernetes resources.
- `kubectl get pvc`: Retrieves information about Persistent Volume Claims (PVCs).
- `kubectl get pv`: Retrieves information about Persistent Volumes (PVs).
- `kubectl get svc`: Retrieves information about services.
- `kubectl get event`: Retrieves information about events in the cluster.
- `kubectl logs (pod-name)`: Displays the logs of a specific pod.
- `kubectl delete pod (name)`: Deletes a specific pod.
- `kubectl delete pvc (name):`
- `kubectl delete pv (name):`
- `kubectl exec -it (pod name) bash`: Executes a command interactively inside a pod, usually used to access a shell.
- `kubectl get pod (pod-name) -o yaml`: Retrieves detailed information about a specific pod in YAML format.
- `kubectl logs (pod-name) -c minecraft-server -f`: Getting status and update in specfic file.
`kubectl port-forward svc/minecraft-server 25575:25575`

#### metal-lb.sh
* important to run this script if you wanna host the local IP and test connection to the server.

```bash
#!/usr/bin/env bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
declare max_ip=$(ipcalc $(docker network inspect -f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' kind | head -n1)  | grep HostMax | tr -s ' ' | cut -f2 -d' ')
declare min_ip=$(ipcalc ${max_ip} 24 | grep HostMin | tr -s ' ' | cut -f2 -d' ' )
kubectl apply -f  <(cat <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: aitomi
  namespace: metallb-system
spec:
  addresses:
  - ${min_ip}-${max_ip}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
)
```

* After finish downloading the script and then run these command in the cluster:
```bash
chmod +x 002-metal-lb.sh
./002-metal-lb.sh
```

##### Usetage of rcon and why you need it
if you wanna host your minecraft-server terminal use rcon. make sure you install it and have it on your computer then you can later run it and host your minecraft-server.
```bash
Downloads/rcon-cli --host IP-ADDRESS --password
```

##### Privacy
In certain parts of the script, you'll notice references to `secretKeyRef` and `key`. These are utilized for concealing sensitive information within a `secret.yaml` file, allowing you to download assets onto your Minecraft server discreetly. To enhance security further, consider incorporating base code into your setup.
```yaml
- name: WORLD
    valueFrom:
       secretKeyRef:
            name: minecraft-secret
                key: WORLD
```

##### Uploading stuff to github
- `git status`
- `git add .`
- `git commit`
- `git push`
- `git log`
- git commit -a (ctrl O, ctrl X "dont forget to enter"), git push

#### Resources

[itzg/docker-mc-backup](https://github.com/itzg/docker-mc-backup)

[itzg/dockor-minecraft-server](https://github.com/itzg/docker-minecraft-server)

[Minecraft server dockor help](https://docker-minecraft-server.readthedocs.io/en/latest/)


##### have fun!!
![cat](https://i.pinimg.com/564x/81/91/1b/81911b4dc9f94e4aec3e1c7c5bdb3729.jpg)