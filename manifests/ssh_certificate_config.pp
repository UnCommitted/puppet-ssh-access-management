class ssh_access_management::ssh_certificate_config (
  # List containing User CA public keys that this host trusts
  $user_ca_keys = {},

  # List of trust Host CA keys that this host trusts
  $trusted_host_ca_keys = {},

  # Allow user managed authorized_keys
  $allow_user_authorized_keys = true,

  # Default options for the KRL retrieval script
  $krl_repo      = 'git@github.com:eResearchSA/ssh-krl.git',
  $krl_clone_dir = '/etc/ssh-krl',
  $krl_file      = 'revoked_keys'
) {

  if $allow_user_authorized_keys {
    ssh::server::configline {
      # Allow the default, which is to look in user home directory
      # for authorized ssh keys.
      'AuthorizedKeysFile':
        value  => '"/etc/ssh_authorized_keys/%u/authorized_keys .ssh/authorized_keys .ssh/authorized_keys2"',
        ensure => "present";
    }
  } else {

    ssh::server::configline {
      # Limit Authorized keys to ones that we know about
      'AuthorizedKeysFile':
        ensure => "present",
        value  => '/etc/ssh_authorized_keys/%u/authorized_keys'; 
    }
  }

  # Configure SSH Public Key Authentication
  ssh::server::configline {
    # Set log level higher to enable better
    # auditing
    'LogLevel':
      ensure => 'present',
      value  => 'VERBOSE'; 

    # Set up host trust settings
    'HostCertificate':
      ensure => 'present',
      value  => '/etc/ssh/host_cert.pub'; 

    # Set up public/private 
    # Note - the actual file needs to be put in
    # on a per host basis.
    'TrustedUserCAKeys':
      ensure => 'present',
      value  => '/etc/ssh/user_ca.pub';

    # The following needs to be copied from a public source.
    'RevokedKeys':
      ensure => 'present',
      value  => "${krl_clone_dir}/${krl_file}"; 
  }

  # Create some of the SSH configuration files.
  file {
    
    # The following will be updated from an external source
    '/etc/ssh/revoked_keys':
      ensure => 'present',
      owner  => 'root',
      group  => 'root',
      mode   => '0644';

    # Data pulled from hiera
    '/etc/ssh/user_ca.pub':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template("${module_name}/user_ca.pub.erb");

    # This needs to be filled in manually with a signed host key
    '/etc/ssh/host_cert.pub':
      ensure => 'present',
      owner  => 'root',
      group  => 'root',
      mode   => '0644';

    # This file contains our known Host CA Public keys
    '/etc/ssh/trusted_host_ca_certs':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template("${module_name}/trusted_host_ca_certs.erb");
  }

  # Global Known Hosts File for our signed host certificates
  File <| title == '/etc/ssh/ssh_config'|> {
    source => "puppet:///modules/${module_name}/ssh_config_certs"
  }

  file {

    # Regularly update the Key Revokation List
    '/usr/local/bin/download_ssh_krl.sh':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template("${module_name}/download_ssh_krl.sh.erb");
  }

  # The following cron job will run every hour to update
  # the SSH KRL.
  cron { 'update_ssh_krl':
    ensure  => 'present',
    command => '/usr/local/sbin/download_ssh_krl.sh',
    user    => 'root',
    hour    => '*/6',
    require => File['/usr/local/bin/download_ssh_krl.sh'];
  }

}
