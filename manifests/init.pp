class ssh_access_management {

  # Create a directory for system managed authorized keys.
  # This file will be used if the ssh_certificate_config class is used
  file {
    '/etc/ssh_authorized_keys':
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0755';
  }

  # Define a type to manage ssh keys
  define authorized_keys ($sshkeys, $ensure = "present", $home = '') {
    # This line allows default homedir based on $title variable.
    # If $home is empty, the default is used.
    $homedir = $home ? {'' => "/home/${title}", default => $home}
    file {
      "${homedir}/.ssh":
        ensure  => "directory",
        owner   => $title,
        group   => $title,
        mode    => 700,
        require => User[$title];

      "${homedir}/.ssh/authorized_keys":
        ensure  => $ensure,
        owner   => $ensure ? {'present' => $title, default => undef },
        group   => $ensure ? {'present' => $title, default => undef },
        mode    => 600,
        require => File["${homedir}/.ssh"],
        content => template("${module_name}/authorized_keys.erb");

      # Set up the global authorized_keys area as well
      "/etc/ssh_authorized_keys/${title}":
        ensure  => 'directory',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File['/etc/ssh_authorized_keys'];

      "/etc/ssh_authorized_keys/${title}/authorized_keys":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => File["/etc/ssh_authorized_keys/${title}"],
        content => template("${module_name}/authorized_keys.erb");
    }
  }
}
