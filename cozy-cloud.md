Ce fichier décrit l'installation de Cozy-Cloud sur une Debian. A ne pas utiliser avec Yunohost.

# Cosy Cloud

## Prerequis

Avoir un serveur de mail pour l'envoi des mails fonctionnel -> PostFix

Attention, chaque sous nom (1 instance) représente 1 utilisateur

On utilise user.mon-domaine.fr comme nom de domaine

Sur GANDI, ajouter 2 redirections CNAME :
*.user -> @
user -> @

Penser à lancer la commande
```bash
adduser www-data ssl-cert pour éviter échec de validation ACME
```
Avoir configuré le site default avec les bonnes redirections en https

## Installation

- https://github.com/cozy/cozy-setup/wiki/2.4.-The-Docker-Way
- https://forum.cozy.io/t/debian-9-erreur-cozy-coclyco/5321/2
- https://github.com/cozy/cozy-coclyco


--> L'image docker est obsolète, il faut passer par l'install classique


-- https://docs.cozy.io/en/tutorials/selfhost-debian/
Créer des mots de passe uniquement avec des caractère alphanumériques car cela est utilisé dans des scripts

vérifier que l'on ping bien sur les adresses :
user.mon-domaine.fr
xxxx.user.mon-domaine.fr

```bash
cozy-coclyco create user.mon-domaine.fr mistermasque@gmail.com
```

Si erreur de création certificat, supprimer le fichier /etc/ssl/private/account.pem

Si problème, on peut supprimer l'instance avec :
```bash
cozy-stack instance remove user.mon-domaine.fr
```
Penser à supprimer la conf nginx sites-available : user.mon-domaine.fr si on veut tout dégager

Lorsque l'on installe de nouvelles applications, il faut regénérer les certificats :

```bash
cozy-coclyco regenerate user.mon-domaine.fr
```

# PostFix

- https://www.codeflow.site/fr/article/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-debian-10

# Configuration des sous domaines

1. Créer un certificat SSL valide et mettre
	- .crt -> /etc/ssl/certs/
	- .key -> /etc/ssl/private/
Limiter les accès chmod 644 sur les 2 fichiers
2. Configurer OpenMediaVault pour écouter sur le port 8443 pour les connexion SSL
3. ajouter le fichier de conf omv-redirect.conf dans /etc/nginx/conf.d
4. S'assurer que les nom du fichier key et crt est bon
4. S'assurer que le hostname de la machine est accessible au client (DNS ou /etc/hosts)

On utilise le nom de domaine user.mon-domaine.fr

Le principe du fichier est qu'il redirige par défaut toutes les requêtes sur le port 443 ou 80 dont le nom de domaine n'est pas connu sur le port 8443
du hostname