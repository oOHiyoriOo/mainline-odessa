# NAT für das Gerät über den Host

Das Telefon hängt als USB-NCM-Gadget am Host und hat `172.16.42.1/24` auf
`usb0`. Es hat **kein** eigenes Uplink — der Host muss die Pakete aus
`172.16.42.0/24` masqueraden und forwarden.

```
[ Telefon 172.16.42.1/24 ] --usb0/NCM-- [ Host: 172.16.42.12/24 ] --uplink--> Internet
```

> **Wichtig:** Die folgenden Befehle laufen **auf dem Host** (ZeroCore), nicht
> im Container. Der Container hat `CapEff=0` (kein `CAP_NET_ADMIN`, kein
> `ip`/`nft`/`iptables`) und kann Netfilter nicht konfigurieren.
> Der Host-Kernel hat `nf_tables`, `nf_nat`, `nft_chain_nat` und
> `nf_conntrack` geladen; NAT funktioniert dort (Docker nutzt es bereits).

## 1. Host: Interfaces ermitteln

```bash
# USB-Seite = Interface mit 172.16.42.x
USBIF=$(ip -4 -o addr show | awk '$4 ~ /^172\.16\.42\./ {print $2; exit}')
# Uplink = Interface, über das 1.1.1.1 wirklich geroutet wird
UPLINK=$(ip route get 1.1.1.1 | sed -n 's/.* dev \([^ ]*\).*/\1/p')

echo "USBIF=$USBIF  UPLINK=$UPLINK"
```

Typische Werte auf diesem Host:

| Seite | Interface | Adresse |
|---|---|---|
| USB-Gadget | `enx9299d2183dc5` (Name = MAC, kann wechseln) | `172.16.42.12/24` |
| Uplink | `enp7s0` (192.168.188.0/24, metric 100) | DHCP |
| Uplink (alternativ) | `wlp6s0` (192.168.179.0/24, metric 600) | DHCP |

## 2. Host: feste Gadget-Adresse (empfohlen)

Die Host-Adresse kam bisher aus einem udhcpd-Lease des Telefons und kann sich
beim Reconnect ändern. Das Telefon braucht sie aber als Default-Gateway.

```bash
# NetworkManager-Profil des USB-Interface dauerhaft festnageln
nmcli con show | grep -i "$USBIF"
sudo nmcli con mod "<NM-Profilname>" \
    ipv4.method manual ipv4.addresses 172.16.42.12/24 \
    ipv4.never-default yes ipv6.method ignore
sudo nmcli con up "<NM-Profilname>"

# Ohne NetworkManager (nur bis zum Reboot):
sudo ip addr replace 172.16.42.12/24 dev "$USBIF"
sudo ip link set "$USBIF" up
# Altlast entfernen: Default-Route, die das Telefon per DHCP verteilt hat
sudo ip route del default via 172.16.42.1 dev "$USBIF" 2>/dev/null || true
```

`ipv4.never-default yes` ist wichtig — sonst setzt der Host eine Default-Route
Richtung Telefon (metric 20101), was hier nichts verloren hat.

## 3. Host: Forwarding + NAT

```bash
sudo sysctl -w net.ipv4.ip_forward=1

# NAT
sudo iptables -t nat -C POSTROUTING -s 172.16.42.0/24 -o "$UPLINK" -j MASQUERADE 2>/dev/null \
  || sudo iptables -t nat -A POSTROUTING -s 172.16.42.0/24 -o "$UPLINK" -j MASQUERADE

# Forwarding (Docker setzt in FORWARD eine DROP-Policy -> Regeln nach oben)
sudo iptables -C FORWARD -i "$USBIF" -o "$UPLINK" -j ACCEPT 2>/dev/null \
  || sudo iptables -I FORWARD 1 -i "$USBIF" -o "$UPLINK" -j ACCEPT
sudo iptables -C FORWARD -i "$UPLINK" -o "$USBIF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
  || sudo iptables -I FORWARD 1 -i "$UPLINK" -o "$USBIF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

Auf Ubuntu 24.04 ist `iptables` das nft-Backend — das passt zum geladenen
`nf_tables`. Reine nftables-Variante (falls kein `iptables` installiert):

```bash
sudo nft add table ip odessa
sudo nft 'add chain ip odessa post { type nat hook postrouting priority srcnat; }'
sudo nft add rule ip odessa post ip saddr 172.16.42.0/24 oifname "$UPLINK" masquerade
sudo nft 'add chain ip odessa fwd { type filter hook forward priority -10; }'
sudo nft add rule ip odessa fwd iifname "$USBIF" oifname "$UPLINK" accept
sudo nft add rule ip odessa fwd iifname "$UPLINK" oifname "$USBIF" ct state established,related accept
```

Achtung: `accept` in einer eigenen Base-Chain beendet Dockers späteres `drop`
nicht. Wenn Docker-Regeln aktiv sind, ist der `iptables -I FORWARD 1`-Weg
zuverlässiger.

### ufw / firewalld

```bash
sudo ufw allow in on "$USBIF"
sudo ufw route allow in on "$USBIF" out on "$UPLINK"
# firewalld:
sudo firewall-cmd --zone=trusted --add-interface="$USBIF" --permanent
sudo firewall-cmd --reload
```

## 4. Gerät: Route und DNS

Auf dem Telefon (SSH `root@172.16.42.1`):

```bash
# Host-Adresse ermitteln (der einzige Peer im /24 außer uns selbst)
PEER=$(ip neigh show dev usb0 | awk '{print $1}' | grep -v '^172\.16\.42\.1$' | head -1)
echo "PEER=$PEER"          # typisch 172.16.42.12, wenn der Host fest genagelt ist

ip route replace default via "$PEER" dev usb0
printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' > /etc/resolv.conf

# Alten apt-Proxy entfernen, sonst geht apt weiter an 172.16.42.16:3128
rm -f /etc/apt/apt.conf.d/99proxy
```

Das Gerät braucht **kein** eigenes Netfilter/NAT dafür — nur Route + DNS.
(Der Geräte-Kernel hat inzwischen `NF_TABLES`, `BRIDGE`, `VETH`,
`OVERLAY_FS` für Docker an Bord; für NAT auf dem Gerät selbst ist das nicht
nötig.)

## 5. Testen

```bash
# auf dem Gerät
ip route                      # default via 172.16.42.12 dev usb0
getent hosts archive.ubuntu.com
apt-get update

# auf dem Host
sudo conntrack -L 2>/dev/null | grep 172.16.42 | head
sudo tcpdump -ni "$USBIF" icmp
```

## 6. Dauerhaft machen

```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

Oder die Regeln in ein eigenes systemd-Unit / NetworkManager-Dispatcher-Skript
packen (`/etc/NetworkManager/dispatcher.d/90-odessa-nat`), damit sie nach
einem Reconnect wieder sitzen.

## 7. Rückgängig

```bash
sudo iptables -t nat -D POSTROUTING -s 172.16.42.0/24 -o "$UPLINK" -j MASQUERADE
sudo iptables -D FORWARD -i "$USBIF" -o "$UPLINK" -j ACCEPT
sudo iptables -D FORWARD -i "$UPLINK" -o "$USBIF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# nft-Variante:
sudo nft delete table ip odessa
```

## Fehlerbilder

| Symptom | Ursache / Fix |
|---|---|
| `ping: Network unreachable` auf dem Gerät | keine Default-Route: `ip route replace default via $PEER` |
| `getent` leer, aber Ping auf IP geht | `/etc/resolv.conf` leer oder falscher Nameserver |
| `apt` hängt bei `172.16.42.16:3128` | alter Proxy in `/etc/apt/apt.conf.d/99proxy` |
| Ping auf 1.1.1.1 geht nicht, Host sieht Pakete | Forwarding/NAT fehlt oder Docker-`FORWARD`-DROP: `iptables -I FORWARD 1 ...` |
| Adresse des Hosts wechselt nach Reconnect | Host-Seite statisch setzen (Abschnitt 2) |
| Host schickt Default-Traffic zum Telefon | stale DHCP-Route: `ip route del default via 172.16.42.1 dev $USBIF` |
