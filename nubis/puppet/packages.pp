$vsql_major_version = '8.1'
$vsql_version = "${vsql_major_version}.1-13"

$tableau_version = '10-5-1'
$tableau_installer_version = '10-5-0'

# Vertica SQL
package { 'vsql':
  ensure          => present,
  provider        => 'rpm',
  name            => 'vertica-client-fips',
  source          => "https://my.vertica.com/client_drivers/${vsql_major_version}.x/${vsql_version}/vertica-client-fips-${vsql_version}.${::architecture}.rpm",
  install_options => [
    '--noscripts',
  ],
}

file { '/etc/vertica-odbc.tmpl':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  require => [
    Package['vsql'],
    Package['unixODBC'],
  ],
  content => @(EOF)
[Vertica]
Description=Vertica
Driver=/opt/vertica/lib64/libverticaodbc.so
EOF
}
->exec { 'Install ODBC Configuration for Vertica':
  command => 'odbcinst -i -d -f /etc/vertica-odbc.tmpl',
  path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
}

file { '/etc/mysql-odbc.tmpl':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  require => [
    Package['mysql-connector-odbc'],
    Package['unixODBC'],
  ],
  content => @(EOF)
[MySQL]
Description=MySQL
Driver=/usr/lib64/libmyodbc5.so
EOF
}
-> exec { 'Install MySQL Configuration for Vertica':
  command => 'odbcinst -i -d -f /etc/mysql-odbc.tmpl',
  path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
}

staging::file { "tableau-server-${tableau_version}.${::architecture}.rpm":
  source  => "https://downloads.tableau.com/tssoftware/tableau-server-${tableau_version}.${::architecture}.rpm",
  timeout => 0,
}
  -> exec { 'rename RPM':
  command => "cp /opt/staging/tableau-server-${tableau_version}.${::architecture}.rpm /opt/$(rpm -q -p --queryformat '%{Name}' /opt/staging/tableau-server-${tableau_version}.${::architecture}.rpm).rpm",
  path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
}

# Tableau and dependencies
package { [
  'fontconfig',
  'fuse',
  'net-tools',
  'bash-completion',
  'freeglut',
  'freetype',
  'fuse-libs',
  'krb5-libs',
  'libXcomposite',
  'libXrender',
  'libxslt',
  'mesa-libEGL',
]:
  ensure => present,
}
-> package { 'tableau-installer':
  ensure   => present,
  provider => 'rpm',
  name     => 'tableau-server-automated-installer',
  source   => "https://raw.githubusercontent.com/tableau/server-install-script-samples/master/linux/automated-installer/packages/tableau-server-automated-installer-${$tableau_installer_version}.noarch.rpm",
}
-> package { 'tableau-postgresql-odbc':
  ensure   => present,
  provider => 'rpm',
  name     => 'tableau-postgresql-odbc',
  source   => 'https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-9.5.3-1.x86_64.rpm',
}

package { 'unixODBC':
  ensure => present,
}
package { 'mysql-connector-odbc':
  ensure => present,
}
