## rsync-server

A `rsyncd`/`sshd` server in Docker. You know, for moving files.  Based on container by the same name by axiom.  Changes include switching to ubuntu:bionic for base, setting up as auto build, few tweaks on paths and names, addition of pipework for odd network needs.


### tl;dr

Start a server (both `sshd` and `rsyncd` are supported)

```
$ docker run \
    --name rsync-server \ # Name it
    -p 8000:873 \ # rsyncd port
    -p 9000:22 \ # sshd port
    -e USERNAME=user \ # rsync username
    -e PASSWORD=pass \ # rsync/ssh password
    -v /your/public.key:/root/.ssh/authorized_keys \ # your public key
    apnar/rsync-server
```

#### `rsyncd`

```
$ rsync -av /your/folder/ rsync://user@localhost:8000/data
Password: pass
sending incremental file list
./
foo/
foo/bar/
foo/bar/hi.txt

sent 166 bytes  received 39 bytes  136.67 bytes/sec
total size is 0  speedup is 0.00
```


#### `sshd`

Please note that you are connecting as the `root` and not the user specified in
the `USERNAME` variable. If you don't supply a key file you will be prompted
for the `PASSWORD`.

```
$ rsync -av -e "ssh -i /your/private.key -p 9000 -l root" /your/folder/ localhost:/data
sending incremental file list
./
foo/
foo/bar/
foo/bar/hi.txt

sent 166 bytes  received 31 bytes  131.33 bytes/sec
total size is 0  speedup is 0.00
```


### Advanced Usage

Variable options (on run)

* `USERNAME` - the `rsync` username. defaults to `user`
* `PASSWORD` - the `rsync` password. defaults to `pass`
* `VOLUME`   - the path for `rsync`. defaults to `/data`
* `ALLOW`    - space separated list of allowed sources. defaults to `192.168.0.0/16 172.16.0.0/12`.
* `WAIT_INT` - wait for this interface to appear before starting services, for use with pipeworks.


##### Simple server on port 873

```
$ docker run -p 873:873 apnar/rsync-server
```


##### Use a volume for the default `/data`

```
$ docker run -p 873:873 -v /your/folder:/data apnar/rsync-server
```

##### Set a username and password

```
$ docker run \
    -p 873:873 \
    -v /your/folder:/data \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    apnar/rsync-server
```

##### Run on a custom port

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/data \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    apnar/rsync-server
```

```
$ rsync rsync://admin@localhost:9999
data            /data directory
```


##### Modify the default volume location

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    data/rsync-server
```

```
$ rsync rsync://admin@localhost:9999
data            /myvolume directory
```

##### Allow additional client IPs

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    -e ALLOW=192.168.8.0/24 192.168.24.0/24 172.16.0.0/12 127.0.0.1/32 \
    apnar/rsync-server
```


##### Over SSH

If you would like to connect over ssh, you may mount your public key or
`authorized_keys` file to `/root/.ssh/authorized_keys`.

Without setting up an `authorized_keys` file, you will be propted for the
password (which was specified in the `PASSWORD` variable).

```
docker run \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    -e ALLOW=192.168.8.0/24 192.168.24.0/24 172.16.0.0/12 127.0.0.1/32 \
    -v /my/authorized_keys:/root/.ssh/authorized_keys \
    -p 9000:22 \
    apnar/rsync-server
```

```
$ rsync -av -e "ssh -i /your/private.key -p 9000 -l root" /your/folder/ localhost:/data
```
