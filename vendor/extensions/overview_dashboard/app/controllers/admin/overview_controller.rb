class Admin::OverviewController < Admin::BaseController
  def export
  	%x[rake spree:export_products]
  end
  
  def import
  	upload = params[:upload]
    name =  upload['datafile'].original_filename
    directory = "tmp/upload/"
    @results = %x[rm #{directory}*.csv]
    path = File.join(directory, name)
    @post = File.open(path, "wb") { |f| f.write(upload['datafile'].read) }
    isZip = params[:type] == "zip"
    if isZip
		@results += %x[unzip -jo "#{path}" -d '#{directory}'] + "\n"
		@results += "ls #{directory}*.csv\n"
		name = %x[ls #{directory}*.csv].strip.scan(/[^\/]*$/)[0]
    end
    @results += "rake spree:import_products file='#{name}' path='#{directory}' hasImages='#{isZip}'"
    @results += %x[rake spree:import_products file="#{name}" path="#{directory}" hasImages=#{isZip}]
    @results.gsub!("\n", "<br>")
    render :action => :index
  end
end
