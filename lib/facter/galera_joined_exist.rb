Facter.add('galera_joined_exist') do
  setcode do
    if File.file?('/var/lib/mysql/gvwstate.dat')
      true
    else
      false
    end
  end
end
