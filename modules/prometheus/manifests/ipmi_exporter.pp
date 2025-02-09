# @summary This module manages prometheus node ipmi_exporter (https://github.com/soundcloud/ipmi_exporter)
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param config_file
#   Path to IPMI exporter configuration file
# @param config_mode
#  The permissions of the configuration files
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service? (default true)
# @param manage_user
#  Whether to create user or rely on external code for that
# @param modules
#  Hash of IPMI exporter modules
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param purge_config_dir
#  Purge config files no longer generated by Puppet
# @param restart_on_change
#  Should puppet restart the service on configuration change? (default true)
# @param service_enable
#  Whether to enable the service from puppet (default true)
# @param service_ensure
#  State ensured for the service (default 'running')
# @param service_name
#  Name of the node exporter service (default 'ipmi_exporter')
# @param user
#  User which runs the service
# @param version
#  The binary release version
# @param proxy_server
#  Optional proxy server, with port number if needed. ie: https://example.com:8080
# @param proxy_type
#  Optional proxy server type (none|http|https|ftp)
# @param unprivileged
#  If true, run the exporter as an unprivileged user and add sudoers entries
class prometheus::ipmi_exporter (
  Stdlib::Absolutepath $config_file                          = '/etc/ipmi_exporter.yaml',
  String[1] $package_name                                    = 'ipmi_exporter',
  String $download_extension                                 = 'tar.gz',
  # renovate: depName=prometheus-community/ipmi_exporter
  String[1] $version                                         = '1.8.0',
  String[1] $package_ensure                                  = 'latest',
  String[1] $user                                            = 'ipmi-exporter',
  String[1] $group                                           = 'ipmi-exporter',
  Prometheus::Uri $download_url_base                         = 'https://github.com/prometheus-community/ipmi_exporter/releases',
  Array[String] $extra_groups                                = [],
  Prometheus::Initstyle $init_style                          = $prometheus::init_style,
  Boolean $purge_config_dir                                  = true,
  Boolean $restart_on_change                                 = true,
  Boolean $service_enable                                    = true,
  Stdlib::Ensure::Service $service_ensure                    = 'running',
  String[1] $service_name                                    = 'ipmi_exporter',
  Prometheus::Install $install_method                        = $prometheus::install_method,
  Boolean $manage_group                                      = true,
  Boolean $manage_service                                    = true,
  Boolean $manage_user                                       = true,
  String[1] $os                                              = downcase($facts['kernel']),
  Optional[String[1]] $extra_options                         = undef,
  Optional[Prometheus::Uri] $download_url                    = undef,
  String[1] $config_mode                                     = $prometheus::config_mode,
  String[1] $arch                                            = $prometheus::real_arch,
  Stdlib::Absolutepath $bin_dir                              = $prometheus::bin_dir,
  Optional[Stdlib::Host] $scrape_host                        = undef,
  Boolean $export_scrape_job                                 = false,
  Stdlib::Port $scrape_port                                  = 9290,
  String[1] $scrape_job_name                                 = 'ipmi',
  Optional[Hash] $scrape_job_labels                          = undef,
  Optional[String[1]] $bin_name                              = undef,
  Boolean $unprivileged                                      = true,
  Hash $modules                                              = {},
  Stdlib::Absolutepath $script_dir                           = '/usr/local/bin',
  Optional[String[1]] $proxy_server                          = undef,
  Optional[Enum['none', 'http', 'https', 'ftp']] $proxy_type = undef,
) inherits prometheus {
  package { 'freeipmi':
    ensure => 'present',
  }
  # Prometheus added a 'v' on the release name before 1.4.0
  if versioncmp ($version, '1.4.0') >= 0 {
    $release = $version
  }
  else {
    $release = "v${version}"
  }

  $real_download_url = pick($download_url,"${download_url_base}/download/v${version}/${package_name}-${release}.${os}-${arch}.${download_extension}")

  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  file { $config_file:
    ensure  => file,
    owner   => $user,
    group   => $group,
    mode    => $config_mode,
    content => epp('prometheus/ipmi_exporter.yaml.epp', { 'modules' => $modules }),
    notify  => $notify_service,
  }

  if $unprivileged {
    # crazy workaround from https://github.com/soundcloud/ipmi_exporter#running-as-unprivileged-user
    sudo::conf { $service_name:
      ensure         => 'present',
      content        => join([
          "${user} ALL = NOPASSWD: /usr/sbin/ipmimonitoring",
          "${user} ALL = NOPASSWD: /usr/sbin/ipmi-sensors",
          "${user} ALL = NOPASSWD: /usr/sbin/ipmi-dcmi",
          "${user} ALL = NOPASSWD: /usr/sbin/ipmi-raw",
          "${user} ALL = NOPASSWD: /usr/sbin/bmc-info",
          "${user} ALL = NOPASSWD: /usr/sbin/ipmi-chassis",
          "${user} ALL = NOPASSWD: /usr/sbin/ipmi-sel",
      ], "\n"),
      sudo_file_name => $service_name,
    }

    file { "${script_dir}/ipmi-sudo.sh":
      owner   => $user,
      group   => $group,
      mode    => '0750',
      content => join([
          '#!/bin/bash',
          'sudo /usr/sbin/$(basename $0) "$@"',
      ], "\n"),
    }

    $sudo_rewrites = [
      'ipmimonitoring',
      'ipmi-sensors',
      'ipmi-dcmi',
      'ipmi-raw',
      'bmc-info',
      'ipmi-chassis',
      'ipmi-sel',
    ]

    $sudo_rewrites.each |String $rewrite| {
      file { "${script_dir}/${rewrite}":
        ensure  => 'link',
        target  => "${script_dir}/ipmi-sudo.sh",
        require => File["${script_dir}/ipmi-sudo.sh"],
      }
    }

    $unprivileged_option = "--freeipmi.path=${script_dir}"
  } else {
    $unprivileged_option = ''
  }

  $options = join([
      "--config.file=${config_file}",
      $extra_options,
      $unprivileged_option,
  ], ' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    export_scrape_job  => $export_scrape_job,
    scrape_host        => $scrape_host,
    scrape_port        => $scrape_port,
    scrape_job_name    => $scrape_job_name,
    scrape_job_labels  => $scrape_job_labels,
    bin_name           => $bin_name,
    require            => Package['freeipmi'],
    proxy_server       => $proxy_server,
    proxy_type         => $proxy_type,
  }
}
