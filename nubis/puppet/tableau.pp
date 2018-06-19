file { "/etc/nubis.d/${project_name}":
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/startup',
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
