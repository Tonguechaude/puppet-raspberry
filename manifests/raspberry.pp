# Configuration de NGINX
class { 'nginx': }

# Redirection HTTP vers HTTPS
nginx::resource::server { 'tonguechaude.fr-http':
  ensure      => present,
  server_name => ['tonguechaude.fr', 'www.tonguechaude.fr'],
  listen_port => 80,
  return      => '301 https://$host$request_uri',
}

# Configuration HTTPS
nginx::resource::server { 'tonguechaude.fr-https':
  ensure      => present,
  server_name => ['tonguechaude.fr', 'www.tonguechaude.fr'],
  listen_port => 443,
  ssl         => true,
  ssl_cert    => '/etc/letsencrypt/live/tonguechaude.fr-0001/fullchain.pem',
  ssl_key     => '/etc/letsencrypt/live/tonguechaude.fr-0001/privkey.pem',
  www_root    => '/var/www/tonguechaude.github.io',
  index_files => ['index.html'],
  location_cfg_append => {
    'try_files' => '$uri $uri/ =404',
  },
  ssl_include => [
    '/etc/letsencrypt/options-ssl-nginx.conf',
    '/etc/letsencrypt/ssl-dhparams.pem',
  ],
}

# Assurer que les fichiers SSL existent
file { '/etc/letsencrypt/live/tonguechaude.fr-0001/fullchain.pem':
  ensure => file,
  source => '',
}

file { '/etc/letsencrypt/live/tonguechaude.fr-0001/privkey.pem':
  ensure => file,
  source => '',
}

file { '/etc/letsencrypt/options-ssl-nginx.conf':
  ensure => file,
  source => '',
}

file { '/etc/letsencrypt/ssl-dhparams.pem':
  ensure => file,
  source => '',
}

# Configuration de Fail2ban
class { 'fail2ban':
  ensure => present,
}

# Configuration de Prometheus
class { 'prometheus':
  ensure => present,
}

# Configuration du serveur Prometheus
class { 'prometheus::server':
  ensure => present,
  listen_address => '0.0.0.0:9090'
}

# Configuration de Grafana
class { 'grafana': 
  ensure => present,
  cfg => {
    server => {
      http_port => 3000,
    },
  },
}

# Configuration d'un utilisateur et d'un dashboard par défaut dans Grafana
grafana::user { 'admin':
  ensure => present,
  password => 'supersecret',
  full_name => 'Tongue chaude',
  email => 'evan.challias@tonguechaude.fr',
}

grafana::dashboard { 'tonguechaude_dashboard':
  ensure => present,
  content => '{
    "title": "Tonguechaude Dashboard",
    "panels": [
      {
        "type": "graph",
        "title": "Tongue chaude graph",
        "targets": [
          {
            "expr": "up",
            "format": "time_series"
          }
      	]
      }
    ]
  }',
}

