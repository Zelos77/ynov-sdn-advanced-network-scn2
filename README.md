# ynov-sdn-advanced-network-scn2
```Projet Réseaux Avancés – Infrastructure pfSense + OSPF + VPN

Objectifs

Concevoir, déployer et superviser une **appliance réseau virtuelle sécurisée** dans un environnement cloud privé simulé, avec :

- Routage dynamique via **FRRouting (OSPF)**
- **Tunnel VPN site-à-site sécurisé** (WireGuard ou IPsec)
- Règles de sécurité via **pfSense (firewall + NAT)**
- Supervision réseau avec **Prometheus** et **Grafana**
- Scripts d’automatisation (Bash) pour chaque rôle réseau
---

Correspondance avec les objectifs pédagogiques

| Exigence pédagogique         | Implémentation technique                   |
|------------------------------|---------------------------------------------------------------|
| Routage dynamique (OSPF)     | FRRouting activé dans pfSense et/ou sur routeur Linux (site B) |
| Tunnel VPN site-à-site       | WireGuard ou IPsec configuré entre Site A ↔ Site B           |
| Firewall et NAT sécurisés    | Règles configurées via GUI pfSense                           |
| Supervision centralisée      | Prometheus + Grafana + node_exporter                         |
| Métriques OSPF/VPN           | Export depuis pfSense ou VM Linux via Prometheus exporters   |
| Automatisation des rôles     | Scripts Bash pour pfSense, routeur Linux, client, monitoring |
| Tests réseau                 | Ping, VPN status, routage dynamique, observabilité           |
| Documentation                | README complet + journal technique + schéma réseau           |

---

Infrastructure VM

| VM        | Rôle                         | IP                  |
|-----------|------------------------------|---------------------|
| `pfsense` | NVA (Firewall + VPN + OSPF)  | 192.168.1.1 / WAN
| `site-a`  | Client local (test, LAN)     | 192.168.10.2
| `site-b`  | VPN peer (routeur FRR ou pfSense) | 192.168.20.1
| `monitor` (optionnel) | Supervision     | 192.168.10.10

---
Déploiement rapide

> S'assurer que les fichiers sont bien encodés en `LF` (pas CRLF)

```bash
vagrant up
```