# Class: galera_proxysql::proxysql::ssl
#
#
class galera_proxysql::proxysql::ssl (
  Stdlib::Filesource $ssl_ca_source_path,
  Stdlib::Filesource $ssl_cert_source_path,
  Stdlib::Filesource $ssl_key_source_path,
  $proxysql_package = $galera_proxysql::params::proxysql_package,
) {

  notify { "test ${proxysql_package}": }

  file {
    default:
      owner   => proxysql,
      group   => proxysql,
      mode    => '0644',
      notify  => Service['proxysql'],
      require => Package[$proxysql_package];
    '/var/lib/proxysql/proxysql-cert.pem':
      source => $ssl_cert_source_path;
    '/var/lib/proxysql/proxysql-ca.pem':
      source => $ssl_cert_source_path;
    '/var/lib/proxysql/proxysql-key.pem':
      mode   => '0640',
      source => $ssl_cert_source_path;
  }

}
