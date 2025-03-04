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
  package_ensure => 'latest',
}

# Configuration de Prometheus
class { 'prometheus::server':
  version        => '2.52.0',
  alerts         => {
    'groups' => [
      {
        'name'  => 'alert.rules',
        'rules' => [
          {
            'alert'       => 'InstanceDown',
            'expr'        => 'up == 0',
            'for'         => '5m',
            'labels'      => {
              'severity' => 'page',
            },
            'annotations' => {
              'summary'     => 'Instance {{ $labels.instance }} down',
              'description' => '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
            }
          },
        ],
      },
    ],
  },
  scrape_configs => [
    {
      'job_name'        => 'prometheus',
      'scrape_interval' => '10s',
      'scrape_timeout'  => '10s',
      'static_configs'  => [
        {
          'targets' => [ 'localhost:9090' ],
          'labels'  => {
            'alias' => 'Prometheus',
          }
        }
      ],
    },
  ],
}

# Configuration de Grafana
class { 'grafana':
  cfg => {
    app_mode => 'production',
    server => {
      http_port => 3000,
    },
  },
  provisioning_datasources => {
    apiVersion  => 1,
    datasources => [
      {
        name      => 'Prometheus',
        type      => 'prometheus',
        access    => 'proxy',
        url       => 'https://tonguechaude.fr:9090/prometheus',
        isDefault => true,
      },
    ],
  }
}

# Configuration d'un utilisateur et d'un dashboard par défaut dans Grafana
grafana_team { 'tongue':
  ensure           => 'present',
  grafana_url      => 'https://tonguechaude.fr:3000',
  grafana_user     => 'admin',
  grafana_password => 'supersecret',
  home_dashboard   => 'Tongue_board',
  organization     => 'tonguechaude.fr',
}
