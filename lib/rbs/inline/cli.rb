# rbs_inline: enabled

require "optparse"

module RBS
  module Inline
    class CLI
      attr_reader :stdout, :stderr #:: IO
      attr_reader :logger #:: Logger

      # @rbs stdout: IO
      # @rbs stderr: IO
      def initialize(stdout: STDOUT, stderr: STDERR) #:: void
        @stdout = stdout
        @stderr = stderr
        @logger = Logger.new(stderr)
        logger.level = :ERROR
      end

      # @rbs args: Array[String]
      # @rbs returns Integer
      def run(args)
        base_path = Pathname("lib")
        output_path = nil #: Pathname?

        OptionParser.new do |opts|
          opts.on("--base=[BASE]", "The path to calculate relative path of files (defaults to #{base_path})") do
            base_path = Pathname(_1)
          end

          opts.on("--output=[BASE]", "The directory where the RBS files are saved at (defaults to STDOUT if not specified)") do
            output_path = Pathname(_1)
          end

          opts.on("--verbose") do
            logger.level = :DEBUG
          end
        end.parse!(args)

        base_path = Pathname.pwd + base_path

        logger.debug { "base_path = #{base_path}, output_path = #{output_path}" }

        targets = args.flat_map do
          path = Pathname(_1)

          if path.directory?
            pattern = path + "**/*.rb"
            Pathname.glob(pattern.to_s)
          else 
            path
          end
        end

        targets.sort!
        targets.uniq!

        count = 0

        targets.each do |target|
          relative_path = (Pathname.pwd + target).relative_path_from(base_path)
          if output_path
            output = output_path + relative_path.sub_ext(".rbs")

            unless output.to_s.start_with?(output_path.to_s)
              raise "Cannot calculate the output file path for #{target} in #{output_path}"
            end

            logger.debug { "Generating #{output} from #{target} ..." }
          else
            logger.debug { "Generating RBS declaration from #{target} ..." }
          end

          logger.debug { "Parsing ruby file #{target}..." }

          if (uses, decls = Parser.parse(Prism.parse_file(target.to_s)))
            writer = Writer.new()
            writer.header("Generated from #{target.relative? ? target : target.relative_path_from(Pathname.pwd)} with RBS::Inline")
            writer.write(uses, decls)

            if output
              unless output.parent.directory?
                logger.debug { "Making directory #{output.parent}..." }
                output.parent.mkpath
              end

              logger.debug { "Writing RBS file to #{output}..." }
              output.write(writer.output)
            else
              stdout.puts writer.output
              stdout.puts
            end

            count += 1
          else
            logger.debug { "Skipping #{target} because `# rbs_inline: enabled` comment not found" }
          end
        end

        stderr.puts "🎉 Generated #{count} RBS files under #{output_path}"

        0
      end
    end
  end
end
