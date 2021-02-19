Facter.add(:galera_is_bootstrap) do
  setcode do
    if system('/usr/bin/systemctl status mysql@bootstrap >/dev/null 2>&1')
      true
    else
      false
    end
  end
end
