# Swift Face Obscuring

This is a super rough implementation of an app which detects faces in an image and applies a filter to hide them. You can tap a face with a bounding box and it will either filter or unfilter the image.

## How it works

### Face detection
Most of this is abstracted away through Apple's Vision SDK. Basically, you can create a `VNDetectFaceRectanglesRequest` which takes a source image and produces a list of `Any` objects which are then cast to `VNFaceObservation` objects. `VNFaceObservation` objects contain the bounds of detected faces in the source image.

The request can then be performed by a `VNImageRequestHandler`.

### Filtering and masking
The actual image processing is handled by `CIImage` which allows `CIFilter`'s to applied to it. Because we only want a filter to be applied to parts of an image (i.e. faces), a mask image must first be created. This mask image says where the filter should be applied on the source image. Once a mask image has been created a `CIBlendWithMask` can be used to blend the filtered image, mask image and source image.

## Future plans
- Associating children with detected face (tagging). This could be tied to child selection in the Story Editor.
  - How will this be stored?
- How will this fit into the Education app in regards to UI/UX
- How will this work on Android and Web?
- Will this feature be destructive to images? I.e. once an image has been changed, can it be unchanged.
