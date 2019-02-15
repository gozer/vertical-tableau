# Define how Apache should be installed and configured
class { 'apache':
  default_vhost => false,
}

class { 'apache::mod::proxy': }
class { 'apache::mod::proxy_http': }
class { 'apache::mod::remoteip':
  proxy_ips => [
    '127.0.0.1',
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
  ],
}

apache::vhost { $project_name:
    port                => 81,
    default_vhost       => true,
    docroot             => '/var/www/html',
    docroot_owner       => 'root',
    docroot_group       => 'root',
    block               => ['scm'],
    setenvif            => [
      'X-Forwarded-Proto https HTTPS=on',
      'Remote_Addr 127\.0\.0\.1 internal',
      'Remote_Addr ^10\. internal',
    ],
    access_log_env_var  => '!internal',
    access_log_format   => '%a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"',
    custom_fragment     => "
# Clustered without coordination
FileETag None
",
    headers             => [
      "set X-Nubis-Version ${project_version}",
      "set X-Nubis-Project ${project_name}",
      "set X-Nubis-Build   ${packer_build_name}",
    ],
    rewrites            => [
      {
        comment      => 'HTTPS redirect',
        rewrite_cond => ['%{HTTP:X-Forwarded-Proto} =http'],
        rewrite_rule => ['. https://%{HTTP:Host}%{REQUEST_URI} [L,R=permanent]'],
      },
      {
        comment      => 'Maintenance In Progress',
        rewrite_cond => [
            '%{REQUEST_URI} !^/health.html',
            '%{ENV:REDIRECT_STATUS} !=503',
            '/var/www/html/maintenance.html -f',
        ],
        rewrite_rule => ['^(.*)$ /$1 [R=503,L]'],
      },
    ],
    error_documents     => [
      {
        'error_code' => '503',
        'document'   => '/outage.html'
      },
    ],

    proxy_preserve_host => true,
    proxy_add_headers   => false,
    proxy_pass          => [
      {
        'path'          => '/',
        'url'           => 'http://localhost:80/',
        'reverse_urls'  => [ 'http://localhost:80/' ],
        'no_proxy_uris' => [ '/outage.html', '/health.html' ],
      },
    ],
}

file { '/var/www/html/outage.html':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    Class['Apache'],
  ],
  source  => 'puppet:///nubis/files/outage.html',
}

file { '/var/www/html/health.html':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    Class['Apache'],
  ],
  source  => 'puppet:///nubis/files/outage.html',
}

file { '/var/www/html/maintenance.html':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    Class['Apache'],
  ],
  source  => 'puppet:///nubis/files/outage.html',
}
