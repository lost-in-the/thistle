# frozen_string_literal: true

# AUTHORED UNRUN. Producer and fresh consumer are separate processes; this file
# is an entry contract for Root's existing installed harness, not a build runner.
# No dependency, install or runtime grant is implied by loading this file.
if $PROGRAM_NAME == __FILE__
  raise 'Run the admitted installed LOS151 producer then fresh consumer; see test/fixtures/los151_generation_comparison/README.md.'
end
