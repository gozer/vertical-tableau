# Define how Apache should be installed and configured
class { 'nubis_apache':
  port => 81,
}

class { 'apache::mod::proxy': }
class { 'apache::mod::proxy_http': }

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
      }
    ],

    error_documents     => [
      {
        'error_code' => '503',
        'document'   => '/outage.html'
      },
    ],

    proxy_preserve_host => true,
    proxy_pass          => [
      {
        'path'         => '/',
        'url'          => 'http://localhost:80/',
        'reverse_urls' => [ 'http://localhost:80/' ],
      },
    ],
}

file { '/var/www/html/outage.html':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    Class['Nubis_apache'],
  ],
  source  => 'puppet:///nubis/files/outage.html',
}
