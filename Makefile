.PHONY: universal xcframework clean

clean:
	rm -rf *.a *.xcframework

ios:
	rm -rf Celestia.xcframework
	mkdir -p ios-framework-out
	mkdir -p ios-framework-out/headers
	mkdir -p ios-framework-out/sim
	mkdir -p ios-framework-out/device

	make -C celestia-node ios
	cp module.modulemap ios-framework-out/headers
	xcodebuild -create-xcframework \
-library ios-framework-out/sim/libcelestia-bridge.a \
-headers ios-framework-out/headers \
-library ios-framework-out/device/libcelestia-bridge.a \
-headers ios-framework-out/headers \
-output Celestia.xcframework
