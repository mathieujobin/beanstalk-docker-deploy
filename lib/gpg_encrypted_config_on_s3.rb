class GpgEncryptedConfigOnS3

  attr_reader :env_prefix, :stage, :s3_url_prefix, :gpg_file_prefix

  def initialize(env_prefix, stage, s3_url_prefix, gpg_file_prefix)
    @env_prefix = env_prefix
    @stage = stage
    @s3_url_prefix = s3_url_prefix
    @gpg_file_prefix = gpg_file_prefix
  end

  def overwrite_local_from_s3
    download_to_temp_file
    system "cp #{tmp_decrypted_env_file} #{decrypted_env_file}"
  end

  def compare_local_with_s3
    download_to_temp_file
    system "diff #{tmp_decrypted_env_file} #{decrypted_env_file}"
  end

  def push_local_to_s3
    system "gpg --batch -c --cipher-algo CAST5 --passphrase #{passphrase} .env.#{stage}.local"
    system "aws s3 cp --acl public-read .env.#{stage}.local.gpg s3://#{s3_url}"
  end

  private

  def gpg_encrypted_file
    ".tmp#{decrypted_env_file}.gpg"
  end

  def tmp_decrypted_env_file
    ".tmp#{decrypted_env_file}"
  end

  def decrypted_env_file
    ".env.#{stage}.local"
  end

  def passphrase
    ENV["#{env_prefix}_#{stage.upcase}_GPG_SECRET"]
  end

  def s3_url
    "#{s3_url_prefix}/#{stage}/#{gpg_file_prefix}-#{stage}.env.gpg"
  end

  def download_to_temp_file
    system "aws s3 cp s3://#{s3_url} #{gpg_encrypted_file}"
    system "gpg --batch --cipher-algo CAST5 --passphrase #{passphrase} -o #{tmp_decrypted_env_file} -d #{gpg_encrypted_file}"
  end
end
