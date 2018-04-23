class { 'fluentd':
  service_ensure => stopped
}

fluentd::configfile { $project_name: }

fluentd::source { 'tabsvc':
  configfile => $project_name,
  type       => 'tail',
  format     => 'none',

  tag        => "forward.${project_name}.tabsvc",
  config     => {
    'read_from_head' => true,
    'path_key'       => 'tailed_path',
    'path'           => '/var/opt/tableau/tableau_server/data/tabsvc/logs/*/*.log',
    'pos_file'       => "/var/log/${project_name}.pos",
  },
}
