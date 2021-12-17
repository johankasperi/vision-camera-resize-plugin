/* globals __resize */
import type { Frame } from 'react-native-vision-camera';

export function resize(
  frame: Frame,
  cropX: number,
  cropY: number,
  cropWidth: number,
  cropHeight: number,
  scaleWidth: number,
  scaleHeight: number
): Frame {
  'worklet';
  // @ts-expect-error Frame Processors are not typed.
  return __resize(
    frame,
    cropX,
    cropY,
    cropWidth,
    cropHeight,
    scaleWidth,
    scaleHeight
  );
}
