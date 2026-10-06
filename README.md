### Google chrome for internet bank on docker sandbox

- Debian trixie (13) with systemd, latest Google Chrome and Warsaw
- The sandbox has a stable machine identity that travels with the image.

#### Usage

```sh
./ibank.sh            # start a session (builds the image on first use)
./ibank.sh save       # persist the session: identity, chrome profile, warsaw state -> ibank:latest (single layer)
./ibank.sh upgrade    # update Debian, Chrome and Warsaw in place, keeping the identity
./ibank.sh build      # rebuild ibank:base from scratch (only used while there is no ibank:latest)
./ibank.sh export [file.tar.gz]   # docker save ibank:latest
./ibank.sh import file.tar.gz     # docker load, on another machine
```

Sessions start from `ibank:latest` and are thrown away when the next one starts, unless saved.
The first session starts from `ibank:base` and creates a new identity: register the device at the
bank, close the browser and run `./ibank.sh save`. From then on `export`/`import` replicate it.
To start over with a new identity, `docker rmi ibank:latest` (and `./ibank.sh build` for fresh software).

On the first visit Warsaw still has to fetch the bank's module: if the site says the security
component didn't load, wait ~30s and reload (F5).

#### Identity

Created by `ibank-init` on the first boot and stored in `/var/lib/ibank`:

- hostname (`IBANK_HOSTNAME` on the first run, default `ibanksandbox`), `/etc/machine-id`, MAC address;
- `/proc/cpuinfo`, `/proc/meminfo` and DMI data (`/sys/class/dmi/id`) of the machine where it was
  created, bind-mounted over the live ones on every boot. Side effects: `MemAvailable` & co. stay
  frozen at the first boot's values, and the CPU flags listed may not match the current host.

Together with the Chrome profile (`/home/bankusr`, cookies encrypted with a portable key thanks to
`--password-store=basic`) and the Warsaw state, this is what the image carries to other machines.
The exported file is equivalent to a logged-in, registered device: keep it private.

#### Options

- `IBANK_URL`: page to open (default `https://www.bb.com.br`).
- `IBANK_X11=tcp`: reach the X server over TCP. Automatic when docker runs inside minikube.

> *NOTE* : XQuartz prevents incoming network connections by default.
> To fix that, launch XQuartz, go to Preferences, Security tab and check both checkboxes.
