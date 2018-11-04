file { '/usr/share/fonts/tableau':
  ensure  => directory,
  recurse => true,
  purge   => false,
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///nubis/files/fonts',
}
-> exec { 'Update font cache':
  command => 'fc-cache -v /usr/share/fonts',
  path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
}
