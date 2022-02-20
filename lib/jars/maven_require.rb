require 'jar_dependencies'
require 'jars/installer'
require 'jars/maven_factory'
require 'jars/gemspec_artifacts'
require 'tempfile'

def maven_require coord=nil
	builder = Jars::RequireMavenBuilder.new
	if coord.nil?
		yield builder 
	else
		builder.jar(coord)
	end
	Jars::RuntimeInstaller.new(builder).execute
end

module Jars
	class RequireMavenBuilder
		def initialize
			@items = []
			@options = {}
		end
		def [](k)
			@options[k]
		end
		def []=(k,v)
			@options[k] = v
		end
		def options
			@options
		end
		def jar(group, artifact=nil, ver='LATEST')
			if artifact.nil?
				@items << "jar #{group.gsub(":", ",")}" 
			else
				@items << "jar #{group}, #{artifact}, #{ver}" 
			end
		end
		def requirements
			@items
		end
	end

	class RuntimeInstaller
		def initialize(builder)
			@options = builder.options
			@list = builder
		end
		def resolve_dependencies_list(file)
			factory = MavenFactory.new(@options)
			maven = factory.maven_new(File.expand_path('../gemspec_pom.rb', __FILE__))
	  
			maven.attach_jars(@list, false)

			maven['outputAbsoluteArtifactFilename'] = 'true'
			maven['includeTypes'] = 'jar'
			maven['outputScope'] = 'true'
			maven['useRepositoryLayout'] = 'true'
			maven['outputDirectory'] = Jars.home.to_s
			maven['outputFile'] = file.to_s
	  
			maven.exec('dependency:copy-dependencies', 'dependency:list')
		end
		def execute
			Tempfile.open("deps.lst") do |deps_file|
				raise LoadError, "Maven Resolve failed (see stdout/stderr)" unless resolve_dependencies_list(deps_file.path)

				puts File.read deps_file.path if Jars.debug?

				jars = Jars::Installer.load_from_maven(deps_file.path)
				raise LoadError, "Maven Resolve returned no results" unless jars.length >= 1
				jars.each do |id|
					require(id.file)
				end
			end
			nil
		end
	end
end