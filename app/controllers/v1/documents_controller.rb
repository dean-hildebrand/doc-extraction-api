module V1
  class DocumentsController < BaseController
    require_scope "documents:write", only: :create
    require_scope "documents:read", only: :show

    def create
      document = Current.organization.documents.build_from_upload(uploaded_file, api_key: Current.api_key)
      document.save!

      render json: DocumentSerializer.call(document), status: :created
    end

    def show
      document = Current.organization.documents.find_by_public_id!(params[:id])

      render json: DocumentSerializer.call(document)
    end

    private

    # A file field holding plain text rather than an upload counts as missing.
    def uploaded_file
      upload = params.require(:file)
      raise ActionController::ParameterMissing, :file unless upload.is_a?(ActionDispatch::Http::UploadedFile)

      upload
    end
  end
end
