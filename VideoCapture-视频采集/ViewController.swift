//
//  ViewController.swift
//  VideoCapture-视频采集
//
//  Created by liweiyou on 17/3/8.
//  Copyright © 2017年 yons. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary


/**
 AVCaptureSession：媒体（音、视频）捕获会话，负责把捕获的音视频数据输出到输出设备中。一个AVCaptureSession可以有多个输入输出：
 AVCaptureDevice：输入设备，包括麦克风、摄像头，通过该对象可以设置物理设备的一些属性（例如相机聚焦、白平衡等）。
 AVCaptureDeviceInput：设备输入数据管理对象，可以根据AVCaptureDevice创建对应的AVCaptureDeviceInput对象，该对象将会被添加到AVCaptureSession中管理。
 
 AVCaptureOutput：输出数据管理对象，用于接收各类输出数据，通常使用对应的子类AVCaptureAudioDataOutput、AVCaptureStillImageOutput、AVCaptureVideoDataOutput、AVCaptureFileOutput，该对象将会被添加到AVCaptureSession中管理。注意：前面几个对象的输出数据都是NSData类型，而AVCaptureFileOutput代表数据以文件形式输出，类似的，AVCcaptureFileOutput也不会直接创建使用，通常会使用其子类：AVCaptureAudioFileOutput、AVCaptureMovieFileOutput。当把一个输入或者输出添加到AVCaptureSession之后AVCaptureSession就会在所有相符的输入、输出设备之间建立连接（AVCaptionConnection）：
 AVCaptureVideoPreviewLayer：相机拍摄预览图层，是CALayer的子类，使用该对象可以实时查看拍照或视频录制效果，创建该对象需要指定对应的AVCaptureSession对象。
 
 
 
 */
class ViewController: UIViewController {

    fileprivate lazy var videoQueue = DispatchQueue.global()
    fileprivate lazy var audioQueue = DispatchQueue.global()
    // MARK:- 懒加载 捕捉会话
    fileprivate lazy var session : AVCaptureSession = AVCaptureSession()
    
    fileprivate var videoInput : AVCaptureDeviceInput?
    fileprivate var videoOutput : AVCaptureVideoDataOutput?
    fileprivate var movieOutput : AVCaptureMovieFileOutput?
    // MARK:- 懒加载
    fileprivate  lazy var previewLayer : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupDevice()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        session.startRunning()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        session.stopRunning()
    }
}




// MARK:- 设置设备初始化值
extension ViewController {
    fileprivate func setupDevice() {
        //1. 创建输入设备 后置摄像头
        guard let captureDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else {
            print("摄像头不可用")
            return;
        }
        guard let device = captureDevices.filter({ $0.position == .front }).first else { return }
        //2.根据输入设备创建数据输入管理对象 相机输入源
        guard let cameraVideoInput = try? AVCaptureDeviceInput(device: device) else { return }
        videoInput = cameraVideoInput
        
        //3.创建话筒输入源
        //3.1.获得话筒设备
        guard let audioCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else { return }
        //3.2.根据设备创建话筒输入源
        guard let audioInput = try? AVCaptureDeviceInput(device: audioCaptureDevice) else { return }
        
        
        //4.初始化输出源
        let movieOutput = AVCaptureMovieFileOutput()
        self.movieOutput = movieOutput
        
        //4.1.设置写入的稳定性 不设置的话也可以写入 不过一般都设置一下
        let connection = movieOutput.connection(withMediaType: AVMediaTypeVideo)
        connection?.preferredVideoStabilizationMode = .auto
        
        //5.添加输入源
        if session.canAddInput(cameraVideoInput) {
            session.addInput(cameraVideoInput)
            
        }
        //        guard let connection = movieOutput?.connection(withMediaType: AVMediaTypeVideo) else { return }
        //
        //        if (connection.isVideoStabilizationSupported) {
        //            connection.preferredVideoStabilizationMode = .auto
        //        }
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
        
        //6.添加输出源
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        
        addNotitficationToDevice(device: device)
        
    }
}

extension ViewController {
    // MARK:- 开始采集视频
    @IBAction func startCapture(_ sender: Any) {
        if session.isRunning {
            return;
        }
        session.startRunning()
        view.layer.insertSublayer(previewLayer, at: 0)
        //.创建一个沙盒路径
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/movie.mp4"
        
        let url = URL(fileURLWithPath: path)
        movieOutput?.startRecording(toOutputFileURL:url , recordingDelegate: self)
        
    }
    
    // MARK:- 结束采集视频
    @IBAction func endCapture(_ sender: Any) {
        movieOutput?.stopRecording()
        
        session.stopRunning()
        
        previewLayer.removeFromSuperlayer()
    }
    // MARK:- 得到相机设备
    fileprivate func getCameraCaptureDeviceWithPosition(position : AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else {
            
            return nil
        }
        
        guard let device = devices.filter({ $0.position == position }).first else { return nil }
        
        return device
    }
    // MARK:- 切换相机
    @IBAction func switchScene(_ sender: Any) {
        //1.获得原来的输入设备
        guard let oldCaptureDevice = self.videoInput?.device else { return }
        
        removeNotificationFromDevice(device: oldCaptureDevice)
        
        //2.获得原来的设备位置
        let oldPositon = oldCaptureDevice.position
        
        var currentPosition : AVCaptureDevicePosition = .front
        
        if oldPositon  == .front || oldPositon == .unspecified {
            currentPosition = .back
        }
        
        //3.根据位置创建输入设备
        guard let currentCaptureDevice = getCameraCaptureDeviceWithPosition(position: currentPosition) else { return }
        
        addNotitficationToDevice(device: currentCaptureDevice)
        //4.根据输入设备创建输入源
        guard let currentCameraInput = try? AVCaptureDeviceInput(device: currentCaptureDevice) else {
            print("获取相机失败")
            return;
        }
        
        
        //5.切换输入源
        //5.1.开启设置
        session.beginConfiguration()
        //5.2.移除原来的输入源
        session.removeInput(videoInput)
        //5.3.添加现在的输入源
        if session.canAddInput(currentCameraInput) {
            session.addInput(currentCameraInput)
            videoInput = currentCameraInput
        }
        //5.4.提交设置
        session.commitConfiguration()
    }
    
}

extension ViewController {
    
    /** 给输入设备添加通知 */
    fileprivate func addNotitficationToDevice(device : AVCaptureDevice)  {
        lockDevice { (captureDevice) in
            captureDevice.isSubjectAreaChangeMonitoringEnabled = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.areaChanged(notification:)), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: device)
    }
    // MARK:- 移除输入设备的通知
    fileprivate func removeNotificationFromDevice(device : AVCaptureDevice) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: device)
    }
    
    
    /** 更改设备的属性的时候先锁定设备 （修改聚焦、闪光灯、曝光等属性的时候） */
    fileprivate func lockDevice(closure:(_ captureDevice : AVCaptureDevice)->()) {
        guard let captureDevice = videoInput?.device else { return }
        
        do {
            try captureDevice.lockForConfiguration()
            closure(captureDevice)
            print("锁定设备成功")
            captureDevice.unlockForConfiguration()
            
        } catch  {
            print("锁定设备失败")
            print(error)
        }
    }
    // MARK:- 输入设备监控区域发生改变的时候的通知
    @objc fileprivate func areaChanged(notification : Notification) {
        print("监控区域发生变化")
    }
}
// MARK:- 废弃的方法
extension ViewController {
    // MARK:- 设置视频的输入输出
    fileprivate func setupVideo() {
        //1.给捕捉会话设置输入源 摄像头作为输入源
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else {
            print("摄像头不可用")
            return
        }
        //1.1.取出前置摄像头
        //        let device = devices.filter { (device : AVCaptureDevice) -> Bool in
        //            return device.position == .front
        //        }.first
        //$0表示取出闭包里面的第一个参数 {}表示的就是闭包 跟上面的代码是一致的
        guard let device = devices.filter({ $0.position == .front }).first else { return }
        
        //2.2.通过device创建AVCaptureInput对象
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else { return }
        
        
        //2.3.将input添加到会话中
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        self.videoInput = videoInput
        //3.给捕捉会话设置输出源
        //3.1.创建输出源
        let output = AVCaptureVideoDataOutput()
        //必须使用串行调度队列来保证视频帧按顺序传送。 sampleBufferCallbackQueue参数可能不为NULL，除非将sampleBufferDelegate设置为nil。
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.videoOutput = output
        
    }
    // MARK:- 设置 音频 的输入输出
    fileprivate func setupAudio() {
        //1.设置音频的输入
        //1.1.获取话筒设备
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else { return }
        //1.2.根据音频设备创建input 需要加try？ 关键字
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        //1.3.将input添加到会话中
        session.addInput(input)
        
        //2.设置音频的输出源
        let output = AVCaptureAudioDataOutput()
        //2.1设置代理
        //必须使用串行调度队列以保证音频样本将按顺序传送。 sampleBufferCallbackQueue参数可能不为NULL，但将sampleBufferDelegate设置为nil时除外。
        output.setSampleBufferDelegate(self, queue: audioQueue)
        //2.2.添加输出源到会话
        session.addOutput(output)
    }
}
// MARK:- 获取到音频数据 AVCaptureAudioDataOutputSampleBufferDelegate
extension ViewController : AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("采集到音频数据-------")
    }
}
// MARK:- 获取到视频数据 AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        //CMSampleBuffer就是每一帧的画面
        print("已经采集到画面")
    }
}

// MARK:- 写入文件 输出源的代理  AVCaptureFileOutputRecordingDelegate
extension ViewController : AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("开始写入")
    }
    /** 必须实现的代理 */
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("end写入")
        let assets = ALAssetsLibrary()
        assets.writeVideoAtPath(toSavedPhotosAlbum: outputFileURL) { (assetURL, error) in
            if ((error ) != nil) {
                print("保存视频失败")
                return;
            }
            
            print("保存视频成功")
        }
        
    }
}
