import React, { useEffect, useState } from 'react';
import { StyleSheet, View, ActivityIndicator } from 'react-native';
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { resize } from 'vision-camera-resize-plugin';

export default function App() {
  const [hasPermission, setHasPermission] = useState(false);

  const devices = useCameraDevices();
  const device = devices.back;

  useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'authorized');
    })();
  }, []);

  const frameProcessor = useFrameProcessor((frame) => {
    'worklet';
    // @ts-expect-error
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const resizedFrame = resize(
      frame,
      0,
      0,
      frame.width / 4,
      frame.height / 4,
      frame.width / 4,
      frame.height / 4
    );
  }, []);

  return (
    <View style={styles.container}>
      {device != null && hasPermission ? (
        <Camera
          style={styles.camera}
          device={device}
          isActive={true}
          frameProcessor={frameProcessor}
        />
      ) : (
        <ActivityIndicator size="large" color="white" />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'black',
  },
  camera: {
    flex: 1,
    width: '100%',
  },
});
