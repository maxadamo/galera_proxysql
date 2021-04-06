Facter.add(:percona_version_facts) do
  setcode do
    if system("mysql --defaults-file=/root/.my.cnf -NBe 'SELECT 1 from DUAL' >/dev/null 2>&1")
      mysql_output = `mysql --defaults-file=/root/.my.cnf -NBe 'SHOW VARIABLES LIKE "version"'`
      mysql_output.to_s.gsub(%r{version[[:space:]]}, '').strip
    else
      '5.7.22-22-57'
    end
  end
end
