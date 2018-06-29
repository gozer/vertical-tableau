file { "/etc/nubis.d/${project_name}":
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/startup',
}

file { "/usr/local/bin/${project_name}-backup":
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/backup',
}

cron { 'backup':
  ensure      => 'present',
  command     => "nubis-purpose coordinator nubis-cron ${project_name}-backup /usr/local/bin/${project_name}-backup save",
  hour        => '4',
  minute      => fqdn_rand(60),
  environment => [
    'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/opt/aws/bin',
  ],
}

file { '/etc/tableau':
  ensure => directory,
  owner  => 'root',
  group  => 'root',
}

file { '/etc/tableau/config.json':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    File['/etc/tableau'],
  ],
  source  => 'puppet:///nubis/files/tableau/config.json',
}

file { '/etc/tableau/reg.json':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  require => [
    File['/etc/tableau'],
  ],
  source  => 'puppet:///nubis/files/tableau/reg.json',
}
