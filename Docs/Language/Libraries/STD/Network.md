# Network

`STD.Network` represents IPv4 and IPv6 with fixed byte arrays rather than a
native `sockaddr`. `parse_ip` accepts strict dotted IPv4 and the usual IPv6
forms without whitespace or name lookup. `format_ip` emits decimal IPv4 or
lowercase RFC 5952 IPv6. Endpoint formatting brackets IPv6 and includes a
numeric `%scope_id` only when nonzero.

`resolve` accepts a nonempty ASCII hostname or literal, a numeric port, family,
and stream/datagram transport. It blocks in the system resolver, copies every
result into portable `Endpoint` values, removes exact duplicates while keeping
resolver order, and reports an empty answer as `not_found`. No implicit IDNA,
service-name lookup, DNS cache, DNSSEC, interface-name scope, or preference
policy is applied.

## TCP bloquant

`STD.Network.TCP` possède les sockets avec les ressources uniques `Stream` et
`Listener`. `connect` accepte directement un `Endpoint`, ou résout un hôte puis
tente ses endpoints de flux dans l'ordre. `listen` impose un backlog positif ;
un port zéro choisit un port éphémère que `local_endpoint` permet d'observer.
`accept` rend ensemble le flux possédé et l'endpoint du pair.

Un `Stream` implémente `IO.Reader` et `IO.Writer`. TCP reste un flux d'octets :
une écriture peut être partielle, plusieurs écritures peuvent être réunies par
une lecture, et aucune frontière de message n'est conservée. `read` ne retourne
zéro qu'après l'EOF ordonné du pair. `shutdown_read` et `shutdown_write` ferment
chacun une moitié du flux de manière idempotente.

Les délais, exprimés en millisecondes, sont optionnels : `null` attend sans
limite, zéro ne demande aucune attente supplémentaire, et une valeur négative
est refusée avec `invalid_input`. Les délais de lecture et d'écriture
s'appliquent à chaque appel sans fermer le flux. `close` consomme explicitement
le propriétaire et rend l'éventuelle erreur de fermeture ; sinon le `drop`
ferme automatiquement le socket exactement une fois.

Les listeners IPv6 sont IPv6-only sur toutes les plateformes. Pour écouter les
deux familles, le programme ouvre explicitement un listener IPv4 et un listener
IPv6. Cette bibliothèque ne fournit ni TLS, ni HTTP, ni proxy, ni mode
non-bloquant ou asynchrone.

## UDP bloquant

`STD.Network.UDP` possède chaque socket dans une ressource unique `Socket`.
`bind` attache le socket à un endpoint et accepte le port éphémère zéro ;
`open` crée un socket IPv4 ou IPv6 sans attachement explicite. La famille
`Family.any` est refusée parce qu'un socket concret doit choisir une famille.

`send_to` remet un datagramme entier au système ou retourne une erreur ; il
n'expose jamais une émission partielle. `receive_from` consomme exactement un
datagramme et rend le nombre d'octets copiés, l'endpoint source et le témoin
`truncated`. Si le buffer est trop petit, le suffixe est jeté avant l'appel
suivant. Un buffer vide distingue donc un datagramme vide
(`count:0, truncated:false`) d'un datagramme non vide
(`count:0, truncated:true`). UDP n'a pas d'EOF.

Les délais de lecture et d'écriture bornent chaque appel sans fermer le socket.
`null` attend sans limite, zéro ne demande aucune attente supplémentaire et une
valeur négative est refusée. `close` consomme le propriétaire en rendant
l'éventuelle erreur ; le `drop` assure sinon la fermeture terminale.

Il n'y a pas de multicast, broadcast activable, socket connecté, contrôle de
fragmentation, données auxiliaires, sélection d'interface, DTLS, polling ou
mode asynchrone. La taille maximale d'un datagramme reste celle acceptée par la
cible et le réseau.
