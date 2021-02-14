Facter.add('galera_never_ran') do
  setcode do
    if File.file?('/var/lib/mysql/grastate.dat')
      false
    else
      true
    end
  end
end
