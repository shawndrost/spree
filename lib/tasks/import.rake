namespace :spree do
  desc "Export Products to CSV File"
  task :export_products => :environment do
    require 'fastercsv'

    products = Product.find(:all)
    puts "Exporting to #{RAILS_ROOT}/public/products.csv"
    FasterCSV.open("#{RAILS_ROOT}/public/products.csv", "w") do |csv|
    
      csv << ["sku", "name", "description", "master_price", "categories", "image_titles" ]

      products.each do |p|
      	categories = ""
      	p.taxons.each{|t|categories += t.name + ","}
      	images = ""
      	p.images.each{|i|images += i.attachment_file_name + ","}
        csv << [p.sku,
                p.name.titleize,
                p.description,
                p.master_price.to_s,
                categories,
                images]
      end
    end

    puts "Export Complete"
  end
  
  desc "Update / Import products from CSV File, expects file=/path/to/import.csv"
  task :import_products => :environment do
  	require 'fastercsv'
	begin
		n = 0
		u = 0
		t = Taxonomy.first
		products = Product.all.clone
		img_dir = ENV['path']
		puts "Loading #{img_dir + ENV['file']}\n"
		FasterCSV.foreach(img_dir + ENV['file']) do |row|
			next if row[0].downcase == "sku"  #skip header row
			#get the product with this sku, then remove it from the array
			product = products.clone.delete_if{ |p| p.sku != row[0] }[0]
			products.delete_if{ |p| p.sku == row[0] }
			if !product
				# Adding new product
				puts "Adding new product: #{row[1]}"
				product = Product.new()
				product.sku = row[0].to_s
				product.deleted_at = nil
				product.available_on = Time.now
				n += 1
			else
				# Updating existing product
				puts "Updating product: #{row[1]}"
				product.taxons = []

				u += 1
			end
			
			product.name = row[1]
			product.description = row[2]
			product.price = row[3].to_d
			#add categories
			row[4].split(",").map{|taxon_name|
			if taxon_name != ""
				begin
					puts "Adding category '#{taxon_name}'"
					taxon = Taxon.find_by_name(taxon_name)
					if !taxon
						puts "Creating new category '#{taxon_name}'"
						taxon = Taxon.new
						taxon.taxonomy_id = taxon.parent_id = t.id
						taxon.name = taxon_name
						taxon.save
					end
					product.taxons << taxon
				rescue
					puts "Error in taxon creation: " + $!
				end
			end
			}
			#add images
			images = product.images.clone
			row[5] ||= []
			row[5].split(",").map{|image_name|
			  begin
				i = images.clone.delete_if{|img| img.attachment_file_name != image_name }[0]
				images.delete_if{|img| img.attachment_file_name == image_name }
				if i 
					puts "image name identical, no changes: #{i.attachment_file_name}"
				elsif ENV['hasImages'] == "true"
					puts "adding #{image_name}"
					begin
						i = Image.new
						File.open(img_dir + image_name){|f| i.attachment = f}
						i.save
						product.images << i
					rescue
						puts "***WARNING: image titled #{image_name} not found in uploaded file(s)."
					end
				elsif !i.nil?
					puts "***WARNING: image titled #{image_name} not found in uploaded file(s)."
				end
			  rescue
				puts "Error in image system: "+$!
			  end
			}
			images.each{|i| 
				puts "deleting #{i.attachment_file_name}" 
				i.delete
			}
			
			product.save!
		end
		d = 0
	#		products.each{|p|
	#			puts "deleting product #{p.name}"
	#			p.delete
	#			d += 1
	#		}
	puts "Import Completed - Added: #{n} | Updated #{u} | Deleted #{d} Products"
     rescue
		puts "CSV file not found, or is improperly formatted: "+$!
     end
   end
end