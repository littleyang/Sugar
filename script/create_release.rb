
require 'pp'

@version  = ARGV[0]
@custom_packages = ARGV[1..-1]

if !@version
  puts "No version specified!"
  exit
end

@packages = ['core','es5','array','date','date_ranges','function','number','object','regexp','string','inflections','language','date_locales']
@default_packages = @packages.values_at(0,1,2,3,4,5,6,7,8,9)
@delimiter = 'console.info("-----BREAK-----");'
@full_path = "release/#{@version}"
@copyright = File.open('release/copyright.txt').read.gsub(/VERSION/, @version)

@precompiled_notice = <<NOTICE
Note that the files in this directory are not prodution ready. They are
intended to be concatenated together and wrapped with a closure.
NOTICE

`mkdir release/#{@version}`
`mkdir release/#{@version}/precompiled`
`mkdir release/#{@version}/precompiled/minified`
`mkdir release/#{@version}/precompiled/development`


def concat
  File.open('tmp/uncompiled.js', 'w') do |file|
    @packages.each do |p|
      content = get_content(p)
      file.puts content = content + @delimiter
    end
  end
end

def get_content(package)
  if package == 'date_locales'
    `cat lib/locales/*`
  else
    File.open("lib/#{package}.js").read
  end
end

def create_development
  full_content = ''
  if @custom_packages.length > 0
    packages = @custom_packages
    type = 'custom'
  else
    packages = @packages
    type = 'full'
  end
  packages.each do |p|
    content = get_content(p)
    File.open("release/#{@version}/precompiled/development/#{p}.js", 'w').write(content)
    full_content << content
  end
  File.open("release/#{@version}/sugar-#{@version}-#{type}.development.js", 'w').write(@copyright + wrap(full_content))
end

def compile
  command = "java -jar script/jsmin/compiler.jar --warning_level QUIET --compilation_level ADVANCED_OPTIMIZATIONS --externs script/jsmin/externs.js --js tmp/uncompiled.js --js_output_file tmp/compiled.js"
  puts "EXECUTING: #{command}"
  `#{command}`
end

def split_compiled
  contents = File.open('tmp/compiled.js', 'r').read.split(@delimiter)
  @packages.each_with_index do |name, index|
    File.open("#{@full_path}/precompiled/minified/#{name}.js", 'w') do |f|
      f.puts contents[index].gsub(/\A\n+/, '')
    end
  end
  `echo "#{@precompiled_notice}" > release/#{@version}/precompiled/readme.txt`
end

def create_packages
  create_package('full', @packages)
  create_package('default', @default_packages)
  if @custom_packages.length > 0
    create_package('custom', @custom_packages)
  end
end

def create_package(name, arr)
  contents = ''
  arr.each do |s|
    contents << File.open("#{@full_path}/precompiled/minified/#{s}.js").read
  end
  contents = @copyright + wrap(contents.sub(/\n+\Z/m, ''))
  ext = name == 'default' ? '' : '-' + name
  File.open("#{@full_path}/sugar-#{@version}#{ext}.min.js", 'w').write(contents)
end

def wrap(js)
  "(function(){#{js}})();"
end

def cleanup
  linked_full_development_file = 'sugar-edge'
  linked_full_minified_file    = 'sugar-edge-full.min'
  linked_default_minified_file = 'sugar-edge-default.min'
  `rm tmp/compiled.js`
  `rm tmp/uncompiled.js`
  `cd release;rm #{linked_full_development_file}.js;ln -s #{@version}/sugar-#{@version}-full.development.js #{linked_full_development_file}.js`
  `cd release;rm #{linked_default_minified_file}.js;ln -s #{@version}/sugar-#{@version}.min.js #{linked_default_minified_file}.js`
  `cd release;rm #{linked_full_minified_file}.js;ln -s #{@version}/sugar-#{@version}-full.min.js #{linked_full_minified_file}.js`
end

concat
compile
split_compiled
create_packages
create_development
cleanup

