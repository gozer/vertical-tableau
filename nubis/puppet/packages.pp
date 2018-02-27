$vsql_major_version = '8.1'
$vsql_version = "${vsql_major_version}.1-13"

$tableau_version = '10-5-1'

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
-> package { 'tableau':
  ensure          => present,
  provider        => 'rpm',
  name            => 'tableau-server',
  source          => "https://downloads.tableau.com/tssoftware/tableau-server-${tableau_version}.${::architecture}.rpm",
  install_options => [
    '--nopre',
  ],
}


