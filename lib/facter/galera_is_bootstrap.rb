Facter.add(:galera_is_bootstrap) do
  setcode do
    if system('/usr/bin/systemctl status mysql@bootstrap')     
      false
    else
      true
    end
  end
end