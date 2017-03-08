//
//  ViewController.swift
//  VideoCapture-视频采集
//
//  Created by liweiyou on 17/3/8.
//  Copyright © 2017年 yons. All rights reserved.
//

import UIKit
import AVFoundation
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
        // Do any additional setup after loading the view, typically from a nib.
    }
}

extension ViewController {
    // MARK:- 开始采集视频
    @IBAction func startCapture(_ sender: Any) {
        //1.设置视频的输入&输出
        setupVideo()
        
        //2.设置音频的输入输出
        setupAudio()
        
        //3.添加写入文件的output
        let movieOutput = AVCaptureMovieFileOutput()
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput
        
        //3.1.设置写入的稳定性 不设置的话也可以写入 不过一般都设置一下
        let connection = movieOutput.connection(withMediaType: AVMediaTypeVideo)
        connection?.preferredVideoStabilizationMode = .auto
        
        //4.给用户看到一个预览图层
        previewLayer.frame = view.bounds
//        view.layer.addSublayer(previewLayer)
        view.layer.insertSublayer(previewLayer, at: 0)
        
        //5.开始采集
        session.startRunning()
        
        //6.开始将采集到的画面写入到文件中
        //6.1.创建一个沙盒路径
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/movie.mp4"
        //6.2.根据路径创建URL
        let url = URL(fileURLWithPath: path)
        //6.3.写入到文件
        movieOutput.startRecording(toOutputFileURL: url, recordingDelegate: self)
        
    }
    
    // MARK:- 结束采集视频
    @IBAction func endCapture(_ sender: Any) {
        movieOutput?.stopRecording()
        
        session.stopRunning()
        
        previewLayer.removeFromSuperlayer()
    }
    
    // MARK:- 切换相机
    @IBAction func switchScene(_ sender: Any) {
        //1.获取之前的镜头（是前置摄像头还是后置的）
        guard var position = videoInput?.device.position else { return }
        
        //2.获取当前应该显示的镜头
        position = position == .front ? .back : .front
        
        //3.根据当前镜头创建Device
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return }
//        let device = devices.filter { ( device: AVCaptureDevice) -> Bool in
//            return device.position == position
//        }.first
        //等同于上面的写法
        guard let device = devices.filter({$0.position == position}).first else { return }
        
        //4.根据当前Device创建input
        guard let input = try? AVCaptureDeviceInput(device : device) else { return }
        
        //5.切换session中的input
        //5.1.一般当切换input或者output的时候先开始配置
        session.beginConfiguration()
        
        //5.2.移除原来的input
        session.removeInput(videoInput)
        
        //5.3.添加新的input
        session.addInput(input)
        
        //5.4.提交配置
        session.commitConfiguration()
        
        //6.记录当前的input
        self.videoInput = input
    }
    
}
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
        if self.videoInput == nil {
            session.addInput(videoInput)
        }
        
        self.videoInput = videoInput
        //3.给捕捉会话设置输出源
        //3.1.创建输出源
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(output)
        
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
        //        print("已经采集到画面")
    }
}

// MARK:- 写入文件 AVCaptureFileOutputRecordingDelegate
extension ViewController : AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("开始写入")
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("end写入")
    }
}
