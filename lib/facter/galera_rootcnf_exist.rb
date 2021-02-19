Facter.add('galera_rootcnf_exist') do
  setcode do
    if File.file?('/root/.my.cnf')
      true
    else
      false
    end
  end
end
