# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require_relative '../lib/thistle/job_mail_template_capture'

class JobMailTemplateCaptureTest < Minitest::Test
  def test_exact_raw_bytes_and_digest_without_erb_evaluation
    bytes = "<%= raise 'must remain inert' %>\n".b + "\xff".b
    Tempfile.create('los148') do |file|
      file.binmode
      file.write(bytes)
      file.flush
      result = Thistle::JobMailTemplateCapture.call(file: file, path: 'app/views/receipt.html.erb')
      assert_equal bytes, result.fetch('content_bytes').pack('C*')
      assert_equal Digest::SHA256.hexdigest(bytes), result.fetch('sha256')
      assert_equal bytes.bytesize, result.fetch('bytes')
      assert_equal 'raw_template_bytes', result.fetch('provenance')
      assert_raises(RangeError) { Thistle::JobMailTemplateCapture.call(file: file, path: 'unused', max_bytes: 1) }
    end
  end

  def test_bound_file_reads_ignore_singleton_application_overrides
    Tempfile.create('los148') do |file|
      file.write('inert'); file.flush
      def file.read(*) = raise('application read override')
      def file.stat(*) = raise('application stat override')
      def file.seek(*) = raise('application seek override')
      assert_equal 'inert', Thistle::JobMailTemplateCapture.call(file: file, path: 'view.erb')['content_bytes'].pack('C*')
    end
    assert_raises(TypeError) { Thistle::JobMailTemplateCapture.call(file: Object.new, path: 'view.erb') }
  end
end
