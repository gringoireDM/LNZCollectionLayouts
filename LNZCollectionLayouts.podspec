Pod::Spec.new do |s|

    s.platform = :ios
    s.version = "1.1.3"
    s.ios.deployment_target = '8.0'
    s.name = "LNZCollectionLayouts"
 	s.summary      = "A swift collection of UICollectionViewLayout subclasses."

  	s.description  = <<-DESC
                   LNZCollectionLayouts is a collection of UICollectionViewLayout subclasses ready to be used to make your collection views custom and more interesting from UX point of view.
                   The layouts currently included are a snap to center layout, an infinite scroll layout and a carousel layout.
                   DESC
                   
    s.requires_arc = true

    s.license = { :type => "MIT" }
	s.homepage = "https://www.pfrpg.net"
    s.author = { "Giuseppe Lanza" => "gringoire986@gmail.com" }

    s.source = {
        :git => "https://github.com/gringoireDM/LNZCollectionLayouts.git",
        :tag => "v1.1.3"
    }

    s.framework = "UIKit"

    s.source_files = "LNZCollectionLayouts/Layouts/**/*.{swift, h}"
end