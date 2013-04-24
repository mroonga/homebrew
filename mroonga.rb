# -*- coding: utf-8 -*-

require 'formula'

class Mroonga < Formula
  homepage 'http://mroonga.github.com/'
  url 'http://packages.groonga.org/source/mroonga/mroonga-3.02.tar.gz'
  sha256 'f8411d1648a7af262a1e87a813d9386fa3c8a3e99a081f699a054933877736e5'

  depends_on 'pkg-config' => :build
  if ARGV.include?("--use-homebrew-mysql")
    depends_on 'mysql'
  end
  if ARGV.include?("--use-homebrew-mariadb")
    depends_on 'mariadb'
  end
    depends_on 'groonga'

  def options
    [
      ["--use-homebrew-mysql", "Use MySQL installed by Homebrew"],
      ["--with-mysql-source=PATH", "MySQL source directory. This option is required without --use-homebrew-mysql"],
      ["--with-mysql-build=PATH", "MySQL build directory (default: guess from --with-mysql-source)"],
      ["--with-mysql-config=PATH", "mysql_config path (default: guess from --with-mysql-source)"],
      ["--with-debug[=full]", "Build with debug option"],
      ["--with-default-parser=PARSER", "Specify the default fulltext parser like --with-default-parser=TokenMecab (default: TokenBigram)"],
    ]
  end

  def patches
    [
    ]
  end

  def install
    if ARGV.include?("--use-homebrew-mysql")
      build_mysql_formula do |mysql|
        Dir.chdir(buildpath.to_s) do
          install_mroonga(mysql.buildpath.to_s,
                          (mysql.prefix + "bin" + "mysql_config").to_s)
        end
      end
    elsif ARGV.include?("--use-homebrew-mariadb")
      build_mariadb_formula do |mysql|
        Dir.chdir(buildpath.to_s) do
          install_mroonga(mysql.buildpath.to_s,
                          (mysql.prefix + "bin" + "mysql_config").to_s)
        end
      end
    else
      mysql_source_path = option_value("--with-mysql-source")
      if mysql_source_path.nil?
        raise "--use-homebrew-mysql or --with-mysql-source=PATH is required"
      end
      install_mroonga(mysql_source_path, nil)
    end
  end

  def test
  end

  def caveats
    <<-EOS.undent
      To install mroonga plugin, run the following command:
         mysql -uroot -e '#{install_sql}'

      To confirm successfuly installed, run the following command
      and confirm that 'mroonga' is in the list:

         mysql> SHOW PLUGINS;
         +---------+--------+----------------+---------------+---------+
         | Name    | Status | Type           | Library       | License |
         +---------+--------+----------------+---------------+---------+
         | ...     | ...    | ...            | ...           | ...     |
         | mroonga | ACTIVE | STORAGE ENGINE | ha_mroonga.so | GPL     |
         +---------+--------+----------------+---------------+---------+
         XX rows in set (0.00 sec)
    EOS
  end

  private
  module Patchable
    def patches
      file_content = path.open do |file|
        file.read
      end
      data_index = file_content.index(/^__END__$/)
      return super if data_index.nil?

      data = path.open
      data.seek(data_index + "__END__\n".size)
      data
    end
  end

  def build_mysql_formula
    mysql = Formula.factory("mysql")
    mysql.extend(Patchable)
    mysql.brew do
      yield mysql
    end
  end

  def build_mariadb_formula
    mysql = Formula.factory("mariadb")
    mysql.extend(Patchable)
    mysql.brew do
      yield mysql
    end
  end

  def build_configure_args(mysql_source_path, mysql_config_path)
    configure_args = [
      "--prefix=#{prefix}",
      "--with-mysql-source=#{mysql_source_path}",
    ]

    mysql_config = option_value("--with-mysql-config")
    mysql_config ||= mysql_config_path
    if mysql_config
      configure_args << "--with-mysql-config=#{mysql_config}"
    end

    mysql_build_path = option_value("--with-mysql-build")
    if mysql_build_path
      configure_args << "--with-mysql-build=#{mysql_build_path}"
    end

    debug = option_value("--with-debug")
    if debug
      if debug == true
        configure_args << "--with-debug"
      else
        configure_args << "--with-debug=#{debug}"
      end
    end

    default_parser = option_value("--with-default-parser")
    if default_parser
      configure_args << "--with-default-parser=#{default_parser}"
    end

    configure_args
  end

  def install_mroonga(mysql_source_path, mysql_config_path)
    ENV.append_to_cflags("-DDISABLE_DTRACE") # Remove me since 3.0.1
    configure_args = build_configure_args(mysql_source_path, mysql_config_path)
    system("./configure", *configure_args)
    system("make")
    system("make install")
    system("mysql -uroot -e '#{install_sql}' || true")
  end

  def install_sql
    sqls = [
      "INSTALL PLUGIN mroonga SONAME \"ha_mroonga.so\";",
      "CREATE FUNCTION last_insert_grn_id RETURNS INTEGER SONAME \"ha_mroonga.so\";",
      "CREATE FUNCTION mroonga_snippet RETURNS STRING SONAME \"ha_mroonga.so\";",
    ]
    sqls.join(" ")
  end

  def option_value(search_key)
    ARGV.options_only.each do |option|
      key, value = option.split(/=/, 2)
      return value || true if key == search_key
    end
    nil
  end
end