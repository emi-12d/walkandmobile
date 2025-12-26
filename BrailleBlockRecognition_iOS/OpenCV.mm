// 2022-5-26　受信
// cv::が必要
#import <opencv2/opencv.hpp>
#import <opencv2/core.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgcodecs/ios.h>

#include <opencv2/core/version.hpp>

#import "OpenCV.h" //ライブラリによってはNOマクロがバッティングするので，これは最後にimport



#include <string>
#include <vector>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>


using namespace std;
using namespace cv;


const double MCosine = 0.7; // 0.7   0.3 低い角度からの画像では四角の角度が鋭角になる 0.4
const int SQmin = 15000; // buffalo = 16000;//25000から変更9/2  18000
const int SQmax = 170000;//ele 100000 135000------> 100000 ----->150000 andoroid Pixel XL---->170000
const int TRmin = 80;//log=200 el=120// 2018-10-26 変更テスト　120---> 100--->80  2019-2-7 変更　７０（６０でもいける） 80---->android Pixel XL
const int TRmax = 900;//Log=900(1m) el=800// 2018-10-26 変更テスト900-->600-----//2020-1-14 700--->900
const int MaxblackPiont = 700; //2021-9-17 通常＝450 ring での試行　追加
//MAT型変換(→8UC3)
cv::Mat cvMatC3(cv::Mat cvMat){
    cv::Mat cvMatC3(cvMat.rows, cvMat.cols,CV_8UC3);
    cvMat.convertTo(cvMatC3, CV_8UC3);
    cvMat.release();
    return cvMatC3;
}

@implementation OpenCV : NSObject
- (NSArray *) reader:(UIImage *)img {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(img.CGImage);
    
    

        //切り抜きサイズに合わせるため、拡大
        //固定値でないと重くなる..
        CGFloat cols = img.size.width;
        CGFloat rows = img.size.height;
        //CGFloat cols = 800;
        //CGFloat rows = 1065

        //printf("%f",cols);
        //printf("%f",rows);


        cv::Mat Img(rows, cols, CV_8UC4);
        cv::Mat image0(rows, cols, CV_8UC3);
        CGContextRef contextRef = CGBitmapContextCreate(Img.data,
                                                        cols,
                                                        rows,
                                                        8,
                                                        Img.step[0],
                                                        colorSpace,
                                                        kCGImageAlphaNoneSkipLast |
                                                        kCGBitmapByteOrderDefault);

        CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), img.CGImage);

        CGContextRelease(contextRef);
        CGColorSpaceRelease(colorSpace);


        image0 = cvMatC3(Img);
        Img.release();
//    cv::Mat *image0 = (__bridge cv::Mat*)img;
//    cv::Mat &image0 = *(Mat *) img;
    int tindex = 0;
    int trindex = 0;
    int sindex = 0;
    int sqindex = 0;
    int sqaindex = 0;


    vector<vector<cv::Point> > tr;// 三角形　エリア 座標 個数オーバーか？　２０－－－＞４０へ 原因不明エラーでストップ　9/14
    //tr.resize(20);
    tr.clear();
    vector<vector<cv::Point> > Tr;// 三角形　エリア 座標 // = vector<Point> tr[10];
    //Tr.resize(20);
    Tr.clear();

    vector<vector<cv::Point> > Sq;// ４角形　エリア 座標 Canny
    //Sq.resize(20);
    Sq.clear();
    vector<vector<cv::Point> > Sqa;// ４角形　エリア 座標 Adaptive
    //Sqa.resize(20);
    Sqa.clear();
    vector<vector<cv::Point> > sq;// ４角形　エリア 座標 duplicate check
    //sq.resize(40);
    sq.clear();


//    cv::Rect rect(0,0,800,720);
//    cv::Rect rect(0,0,400,360);

//    cv::Mat image1(image0,rect);

//    Mat image2(image1.size(),CV_8UC3);
//    cvtColor(image1, image2, COLOR_RGBA2BGR);
//    int invmean0=mean(image2)[0];
    ///////////////////////////////////////////////////////////////////////////////

    ///////////////////ここまで/////////////////////////////////////////////////////
    //移植時改良点
    ////////////////////////////////////////////////////////////
    Mat image=Mat(image0.size(),CV_8UC3);
//    cv::cvtColor(*image0, image, COLOR_RGBA2BGR);
    cv::cvtColor(image0, image, COLOR_RGBA2BGR);

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////

    Mat img1 = Mat(image.size(), CV_8UC3, Scalar(100));// 背景 灰色　３角形ではよい
    Mat img2 = Mat(image.size(), CV_8UC3, Scalar(0));// 背景　黒　for OTSU Sq find
    Mat img3 = Mat(image.size(), CV_8UC3, Scalar(0));// 背景　黒
    Mat img4 = Mat(image.size(), CV_8UC3, Scalar(255));//背景　白


    int invmean=mean(image)[0];

    sqaindex = mask(image, img1, img2, Sqa);
    sindex = findSq(image, img2, Sq);//orignal+ yellow-maskでの抽出　sindex;４角形個数
    if ((sindex + sqaindex) != 0)
        sqindex = Sqcheck(Sq, sindex, Sqa, sqaindex, sq);

    if (sqindex != 0) {//四角形があった場合のみ三角形をその内部で探す
        Trmask(image, sq, sqindex, img3, img4);//img3 black, img4 white-Tr
        tindex = findTr(img3, img4, Tr);
    }
    /////////////////////////////////
    if (tindex != 0)
        trindex = Trcheck(Tr, tindex, tr);// ダブりチェックa
    ///////////////////////////////////////////////////
    //////////////////////////////////////////// Get Code /////////////////
    Code=0;
    Angl=-1;
    int invmeanf;
    int ret = FHomo(image, sq, sqindex, tr, trindex, invmeanf);//image--->image0

    if (ret<0){
      Code=0;
      Angl=-1;
    }

    cv::cvtColor(image, image0, COLOR_BGR2RGBA);
    /////////////////////////////////////////////

//    Ret[0]=ret;
//    Ret[3]=invmean;//画像全体の輝度
//    Ret[4]=invmeanf;//Get_codeへの画像輝度
    if ((ret == 1) || (ret == 0))
    {  // 1:２個取れた時 0:１個取れた時
//        Ret[1] = Code;
//        Ret[2] = Angl;
        if (ret == 0) {// 1個のみ
          ////////////////右上黒　平面ブロックコードは一個だけでもOK 2020-12-15
          if  ((Code < 5242880)||(Code > 6291456)){ // 追加2022/02/19  更新日23/9/7前回数値1048576   2097152
              Code=0; Angl=-1;
          }
        }
        if (ret == 1) {  }//２個以上取れた時}
    }

    NSNumber *code_n = [NSNumber numberWithLong:Code];
    NSNumber *angle_n = [NSNumber numberWithInt:Angl];

    // MARK:-- 緑の線を表示させる
    // 現状、負荷が大きすぎて認識がうまくいかない
    UIImage *resultImg = MatToUIImage(image0);
    NSArray *result = [NSArray arrayWithObjects:code_n,angle_n,resultImg,nil];

    //NSArray *result = [NSArray arrayWithObjects:code_n,angle_n,nil];
    return result;
}





// MARK: -- img1 入力画像　image mask後の返却画像 imageGR ４角形抽出用返却画像　背景黒　修正　6-4 adaptiveのみでマスク 4-30 Lab L でのＣａｎｎｙ追加

static int mask( const Mat& img1, const Mat& image, const Mat& imageGR ,vector<vector<cv::Point> >& sqa )// mask 画像取得
{
    if(img1.empty()) return -1;
    double area,area2;
    Mat m_g,m_r;
    Mat n0;
    Mat nh,nh1,nh2,gray,gray1,l_b;
    Mat yellow=Mat(img1.size(),CV_8UC3);
    Mat mask = Mat::zeros(img1.rows, img1.cols, CV_8UC1);
    Mat mask0 = Mat::zeros(img1.rows, img1.cols, CV_8UC1);

    vector<Mat> plane,plane2,pl0;
//vector<Point> apr;
    //double S,Sa[4];

    vector<cv::Point> approx;
    vector<cv::Point> approx_con;
    vector<cv::Point> approx_con1;
    vector<vector<cv::Point> > contours;// For Lab
    vector<vector<cv::Point> > contours0;
    Mat element = getStructuringElement(MORPH_RECT,cv::Size(3,3));//3,3

    //medianBlur(img1,gray,3);// 2-28 5 to 3　大事　5:だと影では穴があく
    medianBlur(img1,n0,5);// 変更2020/01/20　for andoroid
    //cvtColor(gray, gray1, COLOR_BGR2GRAY);
    cvtColor(n0, gray1, COLOR_BGR2GRAY);

    adaptiveThreshold(gray1,nh,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,11,5);// orignal 下は暗い時はより良いが　影の場合は不明

    cvtColor(n0, nh2, COLOR_BGR2Lab);
    split(nh2, plane2);
    Canny(plane2[0], l_b, 60,180,3);//60 180
    bitwise_or(nh, l_b, nh);
    morphologyEx(nh,gray,MORPH_CLOSE,element,cv::Point(-1,-1),1);
    findContours(gray, contours0, RETR_LIST, CHAIN_APPROX_SIMPLE);
    findContours(l_b, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);///4-30

    int s1=0;
    int s2=0;
    int s3=0;
    int s4=0;
    int aps;
    double cosine,maxCosine;

    for( size_t k = 0; k < contours.size(); k++ )
    {
        if (s1 > 10) break;
        area = contourArea(contours[k]);
        if (area >SQmin && area < SQmax){// 25000  95000
            approxPolyDP(Mat(contours[k]), approx, arcLength(Mat(contours[k]), true)*0.01, true);// 0.01
            aps = approx.size();
            if (aps == 4 ){// 左右周りは不明6-13
                maxCosine = 0;
                for( int j = 0; j < 4; j++ )
                {
                    cosine = fabs(a_angle(approx[j], approx[(j+2)%4], approx[(j+3)%4]));
                    maxCosine = MAX(maxCosine, cosine);
                }
                int check = sqch(approx);
                
                // 2025/7/30 修正
                
                if ((maxCosine < MCosine) && (check == 0)) {
                    // 新しい四角形のためのベクターを作成し、approxの頂点をコピー
                    std::vector<cv::Point> new_square = approx;

                    // sqaの末尾に新しい四角形を追加
                    sqa.push_back(new_square);

                    // 右周りの座標?
                    drawContours(mask0, contours, k, Scalar(255), FILLED);

                    // s1をsqaの実際のサイズに同期させる
                    s1 = (int)sqa.size();
                    s2++;
                }
                

            }
            
            // 2025/7/30
            
            if ((aps > 4 )&&(aps <= 20 )){// 20は適当　検討要する？
                //convexHull(approx, approx_con);
                convexHull(Mat(contours[k]), approx_con);
                area2 = contourArea(approx_con);
                
                if ((approx_con.size() == 4) && (area2 < SQmax)){
                    maxCosine = 0;
                    for( int j = 0; j < 4; j++ )
                    {
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    int check = sqch(approx_con);
                    if(( maxCosine < MCosine )&&(check == 0)){
                        // 新しい四角形のためのベクターを作成し、approx_conをコピー
                        std::vector<cv::Point> new_square = approx_con;
                        // sqaの末尾に新しい四角形を追加
                        sqa.push_back(new_square);
                        
                        // s1をsqaの実際のサイズに同期させる
                        s1 = (int)sqa.size();
                        s3++;
                    }
                }
                if (approx_con.size() > 4 ){
                    approxPolyDP(approx_con, approx_con1, arcLength(approx_con, true)*0.005, true);
                    if ((approx_con1.size() == 4 ) && (area2 < SQmax)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                            cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                            // 新しい四角形のためのベクターを作成し、approx_con1をコピー
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqaの末尾に新しい四角形を追加
                            sqa.push_back(new_square);
                            
                            drawContours(mask0,contours,k,Scalar(255),FILLED);
                            // s1をsqaの実際のサイズに同期させる
                            s1 = (int)sqa.size();
                            s4++;
                        }
                    }
                }
            }

        }
    }

    
    // 2025/7/30 修正
    for( size_t k = 0; k < contours0.size(); k++ )
    {
        if (s1 > 10) break;
        area = contourArea(contours0[k]);
        if (area >SQmin && area < SQmax){// 25000  95000
            approxPolyDP(Mat(contours0[k]), approx, arcLength(Mat(contours0[k]), true)*0.01, true);// 0.01
            aps = approx.size();
            
            // 四角形を検出する最初のブロック
            if (aps == 4 ){
                maxCosine = 0;
                for( int j = 0; j < 4; j++ )
                {
                    cosine = fabs(a_angle(approx[j], approx[(j+2)%4], approx[(j+3)%4]));
                    maxCosine = MAX(maxCosine, cosine);
                }
                int check = sqch(approx);
                if(( maxCosine < MCosine )&&(check == 0)){
                    // 新しい四角形のためのベクターを作成し、approxをコピー
                    std::vector<cv::Point> new_square = approx;
                    // sqaの末尾に新しい四角形を追加
                    sqa.push_back(new_square);
                    
                    drawContours(mask0,contours0,k,Scalar(255),FILLED);
                    s1++;s2++;
                }
            }
            
            // 多角形（aps > 4）を処理するブロック
            if ((aps > 4 )&&(aps <= 20 )){
                convexHull(Mat(contours0[k]), approx_con);
                area2 = contourArea(approx_con);
                
                // convexHullの結果が4つの頂点を持つ場合
                if ((approx_con.size() == 4 ) && (area2 < SQmax)){
                    maxCosine = 0;
                    for( int j = 0; j < 4; j++ )
                    {
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    int check = sqch(approx_con);
                    if(( maxCosine < MCosine )&&(check == 0)){
                        // 新しいベクターを作成し、approx_conをコピー
                        std::vector<cv::Point> new_square = approx_con;
                        // sqaの末尾に新しい四角形を追加
                        sqa.push_back(new_square);

                        drawContours(mask0,contours0,k,Scalar(255),FILLED);
                        s1++;s3++;
                    }
                }
                
                // convexHullの結果が4つより多くの頂点を持つ場合
                if (approx_con.size() > 4 ){
                    approxPolyDP(approx_con, approx_con1, arcLength(approx_con, true)*0.005, true);
                    if ((approx_con1.size() == 4 ) && (area2 < SQmax)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                            cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                            // 新しいベクターを作成し、approx_con1をコピー
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqaの末尾に新しい四角形を追加
                            sqa.push_back(new_square);
                            
                            drawContours(mask0,contours0,k,Scalar(255),FILLED);
                            s1++;s4++;
                        }
                    }
                }
            }
        }
    }

    //imshow("adp-Mask0-approx",mask0);
    //////////////////以下　黄色領域抽出　////////////////////////////////////////

    split(n0, plane);
    threshold(plane[1],m_g,0,255,THRESH_TOZERO | THRESH_OTSU);// green
    threshold(plane[2],m_r,0,255,THRESH_TOZERO | THRESH_OTSU);// red

    pl0.push_back(mask);//黒
    pl0.push_back(m_g);//G
    pl0.push_back(m_r);//R
    merge(pl0,yellow);
    ////// 黄色領域がほぼとれた1-27pm18:39

    cvtColor(yellow,gray, COLOR_BGR2GRAY);
    threshold(gray,nh,5,255,THRESH_BINARY);

    bitwise_or(mask0, nh, nh);//これがないとマスクが真っ黒になる　c270 C525で。エレコムは大丈夫

    img1.copyTo(image,mask0);// Original　image はCV_8UC3にしないと背景色指定できない c1だといつも黒
    img1.copyTo(imageGR,nh);
    return s1;
}





//////////////////////////////////////////////////////////////////////////////
//////////４角形の抽出
// OTSU-canny は　Backgrund は黒で
// 2-18 RGB-Canny+ ---> New-mask ---> RGB-canny + adaptive-canny + OTSU-canny
// New-maskでは輝度が高いところは欠落するので（a-1 t2-800 など）
//
static int findSq( const Mat& image, const Mat& imageGR, vector<vector<cv::Point> >& sq )
{
    vector<cv::Point> approx;
    vector<cv::Point> approx_con,approx_con1;
    vector<vector<cv::Point>> contours;
    vector<vector<cv::Point>> contours1;
    vector<Mat> plane;
    Mat gray,gray1;
    Mat mt,mt1,dest;
    Mat m_b,m_g,m_r;
    Mat mbgr,mbgr0;
    Mat nh,om,am,l_b;
    Mat element = getStructuringElement(MORPH_RECT,cv::Size(3,3));
    Mat close_img;// dilate の代わり
    double area,area2;
    int aps,aps2;
    Mat canny0,canny1;
    ////////////////////////////filter は検討要する
    medianBlur(image,mt,5);// 追加2-20 おかしかったら削除のこと
    ///////////////// TEST 2-2
    Canny(mt, dest, 60,180, 3);

    morphologyEx(dest,mbgr0,MORPH_CLOSE,element,cv::Point(-1,-1),1);
    ////Orignal RGB Canny
    ///////////////////////New-mask での OTSU-Canny ///////yellow-maskに変更　10-29//////
    medianBlur(imageGR,gray,5);// 7にしてもtest2は駄目
    cvtColor(gray,gray1, COLOR_BGR2GRAY);
    double otsu_thresh_val = threshold(gray1, mt, 0, 255, THRESH_BINARY | THRESH_OTSU );
    // mtは常に白で意味なし valの値が０になる時がある！！赤のプレーン、orignalでも
    if (otsu_thresh_val==0) otsu_thresh_val = 60;// 固定値で逃げるか
    // blue or green プレーンのValにするか？
    double lower_thresh_val = otsu_thresh_val * 0.5;
    Canny( gray1, om, lower_thresh_val, otsu_thresh_val );// Cannyの対象は元の画像に
    Canny(gray, mbgr, 60,180, 3);//以下変更２－２
    bitwise_or(mbgr, om, nh);// 追加 2-19 S-OTSU=Canny
    //bitwise_or(am, nh, nh);//without am
    bitwise_or(mbgr0, nh, nh);
    dilate(nh, close_img, Mat(), cv::Point(-1,-1)); // この部分がすべて結果を左右する1-30
    findContours(close_img, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);// Orignal
    findContours(mbgr0, contours1, RETR_LIST, CHAIN_APPROX_SIMPLE);

    int s=0;int s2=0;int s3=0;
    double cosine,maxCosine;


    for( size_t k = 0; k < contours1.size(); k++ )
    {
        if (s > 19) break;
        area = contourArea(contours1[k]);

        if (area > SQmin && area < SQmax){// orignal
            approxPolyDP(Mat(contours1[k]), approx, arcLength(Mat(contours1[k]), true)*0.01, true);// 0.01 0.05以下で
            aps = approx.size();

            // 2025/7/30
            if (aps == 4 && s < 10) {
                //std::cout << approx; // 上から右周りの座標
                // Four corners of source image
                maxCosine = 0; ///// 角度のチェック
                for( int j = 0; j < 4; j++ )
                {
                    //cosine = fabs(a_angle(approx[j%4], approx[j-2], approx[j-1]));
                    cosine = fabs(a_angle(approx[j], approx[(j+2)%4], approx[(j+3)%4]));
                    maxCosine = MAX(maxCosine, cosine);
                }
                int check = sqch(approx);
                if(( maxCosine < MCosine )&&(check == 0)){
                    //if( maxCosine < MCosine ){ ///// 角度のチェック
                    
                    // 新しい四角形のためのベクターを作成し、approxの頂点をコピー
                    std::vector<cv::Point> new_square = approx;
                    
                    // sqの末尾に新しい四角形を追加
                    sq.push_back(new_square);

                    // sをsqの実際のサイズに同期させる
                    s = (int)sq.size();
                    s3++;
                }
            }

            //////if (aps > 4 && aps < 9 && s < 10){/////////////////
            if (aps > 4 && s < 10){

                convexHull(approx,approx_con);// 凸図形に
                //convexHull(Mat(contours[k]),approx_con);// 上と比較して全体で個数が減る？3-5
                //// 0.1とかに大きくするとsizeが２とかになる？？？？1-31
                area2 = contourArea(approx_con);
                aps2 = approx_con.size();
                if ((aps2 == 4)&&(area2 < SQmax)){
                    maxCosine = 0;
                    for( int j = 0; j < 4; j++ )
                    {
                        //cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    int check = sqch(approx_con);
                    
                    // 2025/7/30 修正
                    if ((maxCosine < MCosine) && (check == 0)) {
                        // 新しい四角形のためのベクターを作成し、approx_conの頂点をコピー
                        std::vector<cv::Point> new_square = approx_con;

                        // sqの末尾に新しい四角形を追加
                        sq.push_back(new_square);

                        // sをsqの実際のサイズに同期させる
                        s = (int)sq.size();
                        s3++;
                    }

                    
                }
                ////if ((aps2 > 4)&&(aps2 < 9)&&(area2 < SQmax)){////////*********************
                ///
                // 2025/7/30 修正
                if (aps > 4 && s < 10){
                    convexHull(approx, approx_con);
                    // convexHull(Mat(contours[k]),approx_con);// 上と比較して全体で個数が減る？3-5
                    // 0.1とかに大きくするとsizeが２とかになる？？？？1-31
                    area2 = contourArea(approx_con);
                    aps2 = approx_con.size();
                    
                    // 最初の四角形処理ブロック
                    if ((aps2 == 4) && (area2 < SQmax)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                            // cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                            cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con);
                        if(( maxCosine < MCosine )&&(check == 0)){
                            // 新しいベクターを作成し、approx_conの頂点をコピー
                            std::vector<cv::Point> new_square = approx_con;
                            // sqの末尾に新しい四角形を追加
                            sq.push_back(new_square);
                            // sとs3を更新
                            s = (int)sq.size();
                            s3++;
                        }
                    }
                    
                    // 2つ目の四角形処理ブロック（aps2 > 4 の場合）
                    if ((aps2 > 4) && (area2 < SQmax)){
                        approxPolyDP(approx_con, approx_con1, arcLength(Mat(contours1[k]), true)*0.005, true);
                        // 0.01 で４か５角形 0.005 が一番良いか？2-20
                        
                        // approx_con1が4つの頂点を持つ場合
                        if ((approx_con1.size() == 4 && s < 10) && (area2 < SQmax)){
                            maxCosine = 0;
                            for( int j = 0; j < 4; j++ )
                            {
                                cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                                maxCosine = MAX(maxCosine, cosine);
                            }
                            int check = sqch(approx_con1);
                            if(( maxCosine < MCosine )&&(check == 0)){
                                // 新しいベクターを作成し、approx_con1の頂点をコピー
                                std::vector<cv::Point> new_square = approx_con1;
                                // sqの末尾に新しい四角形を追加
                                sq.push_back(new_square);
                                // sとs3を更新
                                s = (int)sq.size();
                                s3++;
                            }
                        }
                        
                        // approx_con1が5つの頂点を持つ場合
                        if ((approx_con1.size() == 5 && s < 10) && (area2 < SQmax)){
                            vector<cv::Point> quad;
                            Get_quad( approx_con1, quad);
                            maxCosine = 0;
                            for( int j = 0; j < 4; j++ )
                            {
                                cosine = fabs(a_angle(quad[j], quad[(j+2)%4], quad[(j+3)%4]));
                                maxCosine = MAX(maxCosine, cosine);
                            }
                            int check = sqch(quad);
                            if(( maxCosine < MCosine )&&(check == 0)){
                                // 新しいベクターを作成し、quadの頂点をコピー
                                std::vector<cv::Point> new_square = quad;
                                // sqの末尾に新しい四角形を追加
                                sq.push_back(new_square);
                                // sとs3を更新
                                s = (int)sq.size();
                                s3++;
                            }
                        }
                    }
                }

            }
        }
    }
    //////////////////////////////////////////////////////
    ///
    // 2025/7/30 修正
    for( size_t k = 0; k < contours.size(); k++ )
    {
        if (s > 9) break;
        area = contourArea(contours[k]);

        if (area > SQmin && area < SQmax) { // orignal
            approxPolyDP(Mat(contours[k]), approx, arcLength(Mat(contours[k]), true) * 0.01, true); // 0.01 0.05以下で
            aps = approx.size();

            if (aps == 4 && s < 10) {
                //std::cout << approx; // 上から右周りの座標
                // Four corners of source image
                maxCosine = 0; ///// 角度のチェック
                for( int j = 0; j < 4; j++ )
                {
                    cosine = fabs(a_angle(approx[j], approx[(j + 2) % 4], approx[(j + 3) % 4]));
                    maxCosine = MAX(maxCosine, cosine);
                }
                int check = sqch(approx);
                if(( maxCosine < MCosine ) && (check == 0)){
                    // 新しい四角形のためのベクターを作成し、approxをコピー
                    std::vector<cv::Point> new_square = approx;

                    // sqの末尾に新しい四角形を追加
                    sq.push_back(new_square);

                    // sとs2を更新
                    s = (int)sq.size(); // sをsqの実際のサイズに同期させる
                    s2++;
                }
            }
//

            /////if (aps > 4 && aps < 9 && s < 10){////＊＊＊＊＊＊＊＊
            ///
            ///
            ///
            // 2025/7/30
            if (aps > 4 && s < 10) {
                convexHull(approx, approx_con);
                // convexHull(Mat(contours[k]),approx_con);// 上と比較して全体で個数が減る？3-5
                // 0.1とかに大きくするとsizeが２とかになる？？？？1-31
                area2 = contourArea(approx_con);
                aps2 = approx_con.size();

                // 最初の四角形処理ブロック
                // aps2 == 4の場合に四角形を保存
                if ((aps2 == 4) && (area2 < SQmax)) {
                    maxCosine = 0;
                    for (int j = 0; j < 4; j++) {
                        // cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j + 2) % 4], approx_con[(j + 3) % 4]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    int check = sqch(approx_con);
                    if ((maxCosine < MCosine) && (check == 0)) {
                        // 新しいベクターを作成し、approx_conの頂点をコピー
                        std::vector<cv::Point> new_square = approx_con;
                        // sqの末尾に新しい四角形を追加
                        sq.push_back(new_square);
                        // sとs3を更新
                        s = (int)sq.size();
                        s3++;
                    }
                }

                // 2つ目の四角形処理ブロック（aps2 > 4 の場合）
                if ((aps2 > 4) && (area2 < SQmax)) {
                    approxPolyDP(approx_con, approx_con1, arcLength(Mat(contours[k]), true) * 0.005, true);
                    // 0.01 で４か５角形 0.005 が一番良いか？2-20
                    
                    // approx_con1が4つの頂点を持つ場合
                    // この部分も同様に安全な`push_back`に置き換えます。
                    if ((approx_con1.size() == 4 && s < 10) && (area2 < SQmax)) {
                        maxCosine = 0;
                        for (int j = 0; j < 4; j++) {
                            cosine = fabs(a_angle(approx_con1[j], approx_con1[(j + 2) % 4], approx_con1[(j + 3) % 4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if ((maxCosine < MCosine) && (check == 0)) {
                            // 新しいベクターを作成し、approx_con1の頂点をコピー
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqの末尾に新しい四角形を追加
                            sq.push_back(new_square);
                            // sとs2を更新
                            s = (int)sq.size();
                            s2++;
                        }
                    }
                }
            }
            
        }
    }
    //destroyAllWindows();
    if (s == 0) return 0;
    return s;
}






//////// 最初の画像から複数4角形抽出　by Canny
////////////////////////////////////////////////////////////////////////////
//////////sq のダブりを取る////return s ///////3-26 変更　adap-sq 追加/////////////////////////
///////バグ修正する 6-28 x0 y0 x y のイニシャル
const int DD=70;//ダブりの重心範囲
static int Sqcheck(vector<vector<cv::Point> >& sq, int sqindex,vector<vector<cv::Point> >& sqa, int sqaindex, vector<vector<cv::Point> >& Sq )
{
    int s=0;
    int ss=0;
    int onaji=0;
    int x,y,x0,y0;// long から　int へ変更　6-28
// first
    if ((sqindex==0)&&(sqaindex==0)) return 0;
    
    
    // 2025/7/30 修正
    if (sqindex > 0){
        // sqベクターが空でないことを確認してからアクセス
        if (!sq.empty()) {
            // sq[0]ベクター全体をSqの末尾に追加する
            Sq.push_back(sq[0]);
        }
        s = 1;
    } else {
        // sqaベクターが空でないことを確認してからアクセス
        if (!sqa.empty()) {
            // sqa[0]ベクター全体をSqの末尾に追加する
            Sq.push_back(sqa[0]);
        }
        s = 1;
        ss = 1;
    }

    //////////////////////////４角形の重心での比較/////////////
    // 2025/7/30 修正
    // 最初のループ (sqベクターを処理)
    for (int n=1; n<sqindex; n++){
        x0=0;y0=0;// これがなかったため値が全て加算されていた6-28 以下同じ
        for (int i=0; i<4; i++){
            x0+=(int)sq[n][i].x;// 次のｓｑの重心
            y0+=(int)sq[n][i].y;
        }
        x0/=4; y0/=4;
        onaji=0;
        for (int t=0; t<s; t++)// セーブしてあるSq　ｓ個
        {
            x=0;y=0;
            for (int i=0; i<4; i++){
                x+=(int)Sq[t][i].x;// ｓｑの重心
                y+=(int)Sq[t][i].y;
            }
            x/=4; y/=4;
            //　セーブしているｓｑの重心の ある範囲以内なら　同一としてブレイク
            if ( (x0+DD >= x)&&(x0 <= x+DD) && (y0+DD >= y)&&(y0 <= y+DD) )
            { onaji=1;
                break;
            }
        }
        if (onaji==0){
            // Sq[s].push_back(...) を削除し、新しい四角形を安全に追加
            std::vector<cv::Point> new_square = sq[n];
            Sq.push_back(new_square);
            s = (int)Sq.size(); // sをSqのサイズに同期させる
        }
    }
    // もし、Sqに要素がない場合、sが0のままになる可能性があるため、最初の要素は別途追加する必要があります
    // 例: if (!sq.empty()) Sq.push_back(sq[0]);
    // 同様に、sqaの最初の要素も
    // if (!sqa.empty()) Sq.push_back(sqa[0]);

    ///////////////////////////////////////次の４角形 adap///////
    if (sqaindex == 0) return s;

    // 2つ目のループ (sqaベクターを処理)
    for (int n=ss; n<sqaindex; n++){
        x0=0;y0=0;
        for (int i=0; i<4; i++){
            x0+=(int)sqa[n][i].x;// 次のｓｑの重心
            y0+=(int)sqa[n][i].y;
        }
        x0/=4; y0/=4;
        onaji=0;
        for (int t=0; t<s; t++)// セーブしてあるSq　ｓ個
        {
            x=0;y=0;
            for (int i=0; i<4; i++){
                x+=(int)Sq[t][i].x;// ｓｑの重心
                y+=(int)Sq[t][i].y;
            }
            x/=4; y/=4;
            //　セーブしているｓｑの重心の ある範囲以内なら　同一としてブレイク
            if ( (x0+DD > x)&&(x0 < x+DD) && (y0+DD > y)&&(y0 < y+DD) )
            { onaji=1;
                break;
            }
        }
        if (onaji==0){
            // Sq[s].push_back(...) を削除し、新しい四角形を安全に追加
            std::vector<cv::Point> new_square = sqa[n];
            Sq.push_back(new_square);
            //std::cout << sq[n];
            s = (int)Sq.size(); // sをSqのサイズに同期させる
        }
    }
    


    return s;
}







/////////////////////////////////////////////////////////////////
/////////////////とれた四角形によるマスク　この中で三角形をさがす　 ////////背景黒と白の２種類をリターン
static int Trmask(const Mat& image, vector<vector<cv::Point> >& sq, int sqindex, const Mat& trimage, const Mat& trimageW)
{
    if (sqindex == 0) return -1;
    Mat mask = Mat::zeros(image.rows, image.cols, CV_8UC1);//back 黒

    int a0,a1,a2,a3;
    int b0,b1,b2,b3;
    int ax[4],bx[4];
    int sx[4],sy[4];
    double A,Aa[4];
    cv::Point pt[4]; //任意の4点を配列に入れる

    for (int n=0; n < sqindex; n++){ // sqindex は　ＳＱ個数
        for (int i=0; i<4; i++){
            sx[i]=(int)sq[n][i].x;// ax 右回りかどうか不明
            sy[i]=(int)sq[n][i].y;
        }
        ////////////並べ替え　右か左か不明なので　右回りにする/////修正要する　６－１１///////////////////////////////
        A=0;//外積の面積での＋－判断　Ａ＜０なら左回り
        int k=min_return(sy);// となりの点のy値が同じ場合あり、検討
        ax[0]=sx[k];
        bx[0]=sy[k];//一番上
        ax[2]=sx[(k+2)%4];
        bx[2]=sy[(k+2)%4];//反対側の頂点
        for (int i=0;i<4;i++)
        { Aa[i]=sx[i]*sy[(i+1)%4] - sx[(i+1)%4]*sy[i];
            A = A+Aa[i];
        }
        //printf("A=%f",A);
        if (A<0)
        {
            ax[1]=sx[(k+3)%4];
            bx[1]=sy[(k+3)%4];
            ax[3]=sx[(k+1)%4];
            bx[3]=sy[(k+1)%4];
        }
        else{
            ax[1]=sx[(k+1)%4];
            bx[1]=sy[(k+1)%4];
            ax[3]=sx[(k+3)%4];
            bx[3]=sy[(k+3)%4];
        }

        a0 = ax[0];  b0 = bx[0];      //四角形の座標　上から右回りを左回りに 1-23
        a1 = ax[3];  b1 = bx[3];
        a2 = ax[2];  b2 = bx[2];
        a3 = ax[1];  b3 = bx[1];

        pt[0] = cv::Point(a0, b0);
        pt[1] = cv::Point(a1, b1);
        pt[2] = cv::Point(a2, b2);
        pt[3] = cv::Point(a3, b3);
        //描画　引数は (画像, 点の配列, 点の数, 色)
        fillConvexPoly( mask, pt, 4, Scalar(255) );

    }// SQ for文
    //imshow("Mask?", mask );
    image.copyTo(trimage,mask);
    //imshow("TR-Image", trimage );// 黒背景
    image.copyTo(trimageW,mask);// 白背景
    //imshow("TR-ImageW", trimageW );

    return 0;    ////////////////////////////////
}



////////////////////////////////////////////
static int findTr( const Mat& image, const Mat& imageW, vector<vector<cv::Point> >& tr )
{   vector<vector<cv::Point> > contours;
    vector<vector<cv::Point> > contours1;
    vector<vector<cv::Point> > contours2;
    vector<cv::Point> approx;
    Mat element = getStructuringElement(MORPH_RECT,cv::Size(3,3));
    double area;
    Mat mt,mt0,mt1,mt2;
    Mat gray(image.size(), CV_8U);
    Mat gray0;
    Mat grayw(image.size(), CV_8U);

    //imshow("image3",image);
    //imshow("image4",imageW);
    medianBlur(image,mt,5);
    cvtColor(mt, gray, COLOR_BGR2GRAY);// 黒

    medianBlur(imageW,mt,5);
    cvtColor(mt, gray0, COLOR_BGR2GRAY);//　白
    bitwise_not(gray0,grayw);//inverce 白
//////////////////////////Canny
    Canny( gray, gray0, 60, 180,3 );
    //imshow("Gray-TRCanny",gray0);
    morphologyEx(gray0,mt0,MORPH_CLOSE,element,cv::Point(-1,-1),1);// 三角頂点がつながらないケースあり必要2019-12-29
    //imshow("Gray-mor-TRCanny",mt0);

    /// Gray-adaptive での３角形抽出　//////////////////////////////////////////
    adaptiveThreshold(gray,mt1,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);// 通常の黒三角はこれでOK　従来どおり

    //adaptiveThreshold(gray1,mt1,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);
    //imshow("White-TR-41-21", mt1);
    adaptiveThreshold(grayw,mt2,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,15);//白三角はこちらの方がよいかも？
    //imshow("TR-White-41-15", mt1);
    findContours(mt0, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);
    findContours(mt1, contours1, RETR_LIST, CHAIN_APPROX_SIMPLE);
    findContours(mt2, contours2, RETR_LIST, CHAIN_APPROX_SIMPLE);

    int t=0;              // 三角形個数
    
    // 2025/7/30 修正
    for( size_t i = 0; i < contours.size(); i++ )
    {
        if (t > 19) break;
        area = contourArea(contours[i]);
        if (area > TRmin && area < TRmax){  //画像サイズ640の時100　1000なら200
            // 直線近似
            approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.05, true);//0.05
            //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
            if (approx.size() == 3 && t < 20 ){

                polylines(image, approx, true, Scalar(255,0,0), 2);// Test表示はここ
                // imshow("TR-Canny", image);
                
                // Three corners of source image is saved to tr[]
                // 新しい三角形のためのベクターを作成し、approxの頂点をコピー
                std::vector<cv::Point> new_triangle = approx;

                // trの末尾に新しい三角形を追加
                tr.push_back(new_triangle);

                // tをtrの実際のサイズに同期させる
                t = (int)tr.size();
            }
        }
    }

    //////////////////
    // 2025/7/30 修正
    for( size_t i = 0; i < contours1.size(); i++ )
    {
        if (t > 19) break;
        area = contourArea(contours1[i]);
        if (area > TRmin && area < TRmax){ //画像サイズ640の時100　1000なら200
            approxPolyDP(Mat(contours1[i]), approx, arcLength(Mat(contours1[i]), true)*0.05, true);//0.05
            //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
            if (approx.size() == 3 && t < 20 ){
                ///
                
                polylines(image, approx, true, Scalar(255,0,0), 2);// Test表示はここ
                // imshow("TR-Black", image);
                
                // Three corners of source image is saved to tr[]
                // 新しい三角形のためのベクターを作成し、approxの頂点をコピー
                std::vector<cv::Point> new_triangle = approx;

                // trの末尾に新しい三角形を追加
                tr.push_back(new_triangle);

                // tをtrの実際のサイズに同期させる
                t = (int)tr.size();
            }
        }
    }
    for( size_t i = 0; i < contours2.size(); i++ )
    {
        if (t > 19) break;
        area = contourArea(contours2[i]);
        if (area > TRmin && area < TRmax){  //画像サイズ640の時100　1000なら200
            approxPolyDP(Mat(contours2[i]), approx, arcLength(Mat(contours2[i]), true)*0.05, true);//0.05
            //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
            if (approx.size() == 3 && t < 20 ){
                ///
                
                polylines(image, approx, true, Scalar(255,0,0), 2);// Test表示はここ
                // imshow("TR-White", image);
                
                // Three corners of source image is saved to tr[]
                // 新しい三角形のためのベクターを作成し、approxの頂点をコピー
                std::vector<cv::Point> new_triangle = approx;

                // trの末尾に新しい三角形を追加
                tr.push_back(new_triangle);

                // tをtrの実際のサイズに同期させる
                t = (int)tr.size();
            }
        }
    }

    /////////////////////////////////////////////
    if (t == 0)  return 0;
    return t;
}



//////////////////////////////////////////////////////////////
/////////////Trcheck ３角形のダブりチェック 6-21 修正　バグ修正　２０１９－２－２０ 　　　全面修正２０１９－６－２３

const int TT=10;//ダブりの誤差範囲 ±３以下// 10より変更
//////////////////////
static int Trcheck(vector<vector<cv::Point> >& tr, int tindex, vector<vector<cv::Point> >& Tr )
{
    if (tindex == 0) return 0;
    int s=0;
    //int ss=0;
    int onaji=0;
    int x,y,x0,y0;
    double lt[3];// 三角形の辺長の二乗
    int tx[3],ty[3];
    //int sx[3],sy[3];
    // 一番目
    //          Tr[0].push_back(Point(tr[0][0].x, tr[0][0].y));
    //          Tr[0].push_back(Point(tr[0][1].x, tr[0][1].y));
    //          Tr[0].push_back(Point(tr[0][2].x, tr[0][2].y));
    //Tr[0].push_back(Point(tr[0][3].x, tr[0][3].y));// Black or White Tr 2019-6-28
    //          s=1;

    //std::cout << Tr[0];
    for (int n=0;n<tindex; n++){

        x0=0;y0=0;// これがなかったため値が全て加算されていた6-28 以下同じ
        for (int i=0; i<3; i++){
            tx[i] = (int)tr[n][i].x;//追加　２０１９－１１－１８
            ty[i] = (int)tr[n][i].y;//追加　２０１９－１１－１８

            x0+=(int)tr[n][i].x;// 次のtrの重心
            y0+=(int)tr[n][i].y;
        }
        x0/=3;   y0/=3;
        ////////////////////////////////////////////////////////////////////////////////////
        lt[0] = (tx[0]-tx[1])*(tx[0]-tx[1]) + (ty[0]-ty[1])*(ty[0]-ty[1]);
        lt[1] = (tx[1]-tx[2])*(tx[1]-tx[2]) + (ty[1]-ty[2])*(ty[1]-ty[2]);
        lt[2] = (tx[2]-tx[0])*(tx[2]-tx[0]) + (ty[2]-ty[0])*(ty[2]-ty[0]);
        int jmax = maxtd_return(lt);
        int jmin = mintd_return(lt);
        //printf("TRMax=%lf TRMin=%lf\n",lt[jmax],lt[jmin]);
        if (lt[jmax] > lt[jmin]*25) { printf("\nTR-length Err \n"); continue;}//長辺が短辺の５倍以上なら除外２０１９－１１－１８
        //printf( "Next =%d ax,ay=%d %d cx,cy=%d %d",n, ax,ay,cx,cy );
        onaji=0;
        for (int t=0; t<s; t++)// セーブしてあるTr　ｓ個
        {
            x=0;y=0;
            for (int i=0; i<3; i++){
                x+=(int)tr[t][i].x;// trの重心
                y+=(int)tr[t][i].y;
            }
            x/=3;  y/=3;
            //　セーブしているｓｑの重心の ある範囲以内なら　同一としてブレイク
            if ( (x0+TT >= x)&&(x0 <= x+TT) && (y0+TT >= y)&&(y0 <= y+TT) )
            { onaji=1;
                //printf("same=%d",t);
                break;
            }
        }
        // 2025/7/30 修正
        if (onaji == 0) {
            // 新しい三角形のためのベクターを作成し、tr[n]をコピー
            std::vector<cv::Point> new_triangle = tr[n];

            // Trの末尾に新しい三角形を追加
            Tr.push_back(new_triangle);

            // Trf[s] = Trf[n]; の代わりに、安全な方法でTrfに要素を追加
            // たとえば、Trfもstd::vectorであれば
            // Trf.push_back(Trf[n]);

            // sをTrの実際のサイズに同期させる
            s = (int)Tr.size();
        }
//        if (onaji==0){
//            Tr[s].push_back(cv::Point(tr[n][0].x, tr[n][0].y));
//            Tr[s].push_back(cv::Point(tr[n][1].x, tr[n][1].y));
//            Tr[s].push_back(cv::Point(tr[n][2].x, tr[n][2].y));
//            //Trf[s] = Trf[n];// Black or White TR
//            //printf("push=%d",n);
//            //  std::cout << tr[n];
//            s++;
//        }
    }
    return s;
}



////////////////////////////////////////////////////////////////////////////////
static int Angl=-1;// angl  から　Angl　へ変更　6-26
static long Code=0;
static int TRC=8;// 射影後の三角形のブレ範囲 +-5
/////// return -1  0;１個のみ取れた時　1:２個取れた時　正常はコードCode Angl を返す
// Break  continue の使い方ミスで変更　2019-6-24
static int FHomo(const Mat& image, vector<vector<cv::Point> >& sq, int sqindex, vector<vector<cv::Point> >& tr, int trindex, int &invmeanf)
{
    if ((sqindex == 0)||(trindex == 0)) return -1;
    //printf("FHomo=SQ=%d TR=%d ",sqindex,trindex);
    Mat img = image.clone();
    int m=0;//for Tr
    int n=0;//for Sq
    int a0,a1,a2,a3;
    int b0,b1,b2,b3;
    int ax[4],bx[4];
    int tx[3],ty[3];
    int sx[4],sy[4];
    int minx,maxx,miny,maxy;
    int cindex=0;
    int flag=0;// 一つの４角形でコードが一つ見つかった場合　次の４角形の処理へ進む
    int angl=-1;        // 0(-45-45) 1(-45-135) 2(-135- 135) 3(135-45)左周り
    long code[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};// code の最終チェック
    int tmx[20] =   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};// 該当３角形の添字領域
    int Angle[20] =   {-1,-1,-1,-1,-1, -1,-1,-1,-1,-1, -1,-1,-1,-1,-1, -1,-1,-1,-1,-1};
    double A,Aa[4];//外積SQ
    double B,Ba[3];//外積TR

    for (n=0; n < sqindex; n++){

        //    areaS = contourArea(sq[n]);//４角形の面積　３角包含チェックで使用
        // sqindex は　ＳＱ個数
        for (int i=0; i<4; i++){
            sx[i]=(int)sq[n][i].x;// ax 右回りかどうか不明
            sy[i]=(int)sq[n][i].y;
        }
        //printf("\n    SQ-Shori-No.=%d \n",n);
        ////////////並べ替え　右か左か不明なので　右回りにする/////修正要する　６－１１///////////////////////////////
        A=0;//外積の面積での＋－判断　Ａ＜０なら左回り
        int k=min_return(sy);// となりの点のy値が同じ場合あり、検討
        ax[0]=sx[k];
        bx[0]=sy[k];//一番上
        ax[2]=sx[(k+2)%4];
        bx[2]=sy[(k+2)%4];//反対側の頂点
        for (int i=0;i<4;i++)
        { Aa[i]=sx[i]*sy[(i+1)%4] - sx[(i+1)%4]*sy[i];
            A = A+Aa[i];
        }
        //printf("A=%f",A);
        if (A<0)
        {
            ax[1]=sx[(k+3)%4];
            bx[1]=sy[(k+3)%4];
            ax[3]=sx[(k+1)%4];
            bx[3]=sy[(k+1)%4];
        }
        else{
            ax[1]=sx[(k+1)%4];
            bx[1]=sy[(k+1)%4];
            ax[3]=sx[(k+3)%4];
            bx[3]=sy[(k+3)%4];
        }

        a0 = ax[0];  b0 = bx[0];      //四角形の座標　上から右回りを左回りに 1-23
        a1 = ax[3];  b1 = bx[3];
        a2 = ax[2];  b2 = bx[2];
        a3 = ax[1];  b3 = bx[1];

        int j=min_return(ax);//
        minx = ax[j];
        j=max_return(ax);
        maxx=ax[j];
        j=min_return(bx);
        miny=bx[j];
        j=max_return(bx);
        maxy=bx[j];
// この部分　三角形包含OK以降にすべき　2019-3-13  ――→　ダメ　変な四角をとるため　BUのエラー音声をやめる
        /////////////横の辺が上部短辺の2倍以上あるときは除外　8-12 ////カメラが横向きで斜め//////////////////////////
        ///この部分？？？？？？？？？？２０１８－５－２０　バグあり？
        //printf("size-check start");
        double m1=4*((a1-a0)*(a1-a0)+(b1-b0)*(b1-b0));
        double m2=((a2-a1)*(a2-a1)+(b2-b1)*(b2-b1));
        //printf( "M1 M2=%lf %lf\n", m1,m2 );
        if (b1<=b3)
            if (m1<m2) {
                //PlaySound("bu.wav",NULL,SND_FILENAME | SND_ASYNC | SND_NOSTOP);
                //この部分再生タイミングによっては正常のコード音声が再生されない場合あり、コメントに2018-5-22
                //  PlaySound("camera-err.wav",NULL,SND_FILENAME | SND_ASYNC | SND_NOSTOP);
                //  polylines(image, sq[n], true, Scalar(255, 0, 0), 2);
                //    imshow("ERR-SQ-TR", image);
                printf("Camera dist err1");
                continue;
            }
        if (b1>b3)
            if (4*((a3-a0)*(a3-a0)+(b3-b0)*(b3-b0)) < ((a3-a2)*(a3-a2)+(b3-b2)*(b3-b2))) {
                //PlaySound("bu.wav",NULL,SND_FILENAME | SND_ASYNC | SND_NOSTOP);
                //  PlaySound(".wav",NULL,SND_FILENAME | SND_ASYNC | SND_NOSTOP);
                printf("Camera dist err2");//waitKey(0);
                continue;
            }
        //printf("Fhomo-SQ-size-ok");
        //polylines(image, sq[n], true, Scalar(255, 0, 0), 2);
        //imshow("FHomo-SQ", image);
        ////// 以下エラー処理必要　０割り算
        //printf(" SQ-N=%d a0 b0  a1 b1  a2 b2  a3 b3  =%d %d  %d %d  %d %d  %d %d ",n, a0,b0,a1,b1,a2,b2,a3,b3);
        double b_2=0,b_3=0,b_4=0,b_5=0;
        if(a0 != a1)
            b_2=(a0*b1-a1*b0)/(a0-a1);// 線分　一次方程式　y=ax+b　の　bの値
        if(a2 != a1)
            b_3=(a1*b2-a2*b1)/(a1-a2);
        if(a2 != a3)
            b_4=(a2*b3-a3*b2)/(a2-a3);
        if(a3 != a0)
            b_5=(a3*b0-a0*b3)/(a3-a0);

        for (m=0; m < trindex; m++){
            int idx=0;
            double S;

            for ( int i=0; i<3; i++){ // ３角形の頂点座標　３点とも４角形内にあるか? この部分おかしいバグあり１１－２７
                tx[i]=(int)tr[m][i].x;
                ty[i]=(int)tr[m][i].y;
                ////////////////この部分？？？？？修正？１１－２７　ＯＫ？
                // if ( a1>=tx[i] || a3<=tx[i] || ty[i]<=b0 || ty[i]>=b2)
                if ( minx>=tx[i] || maxx<=tx[i] || ty[i]<=miny || ty[i]>=maxy)
                { //printf("break Tr-No.=%d \n",m);
                    //
                    break;}
                /////////////////////
                if ( a1<tx[i] && tx[i]<=a0  && b0<ty[i] && ty[i]<=b1 ){// Case2 内にあり
                    S = tx[i]*(b0-b1)/(a0-a1) + b_2;
                    //if ( ty[i] < ( (b0-b1)/(a0-a1)*tx[i] + b_2 ) ) break; 計算途中小数点になるので駄目
                    if ( ty[i] < S ) {//printf("break Tr-No.=%d \n",m);
                        break;}// エリア内にない
                }
                if ( tx[i]>a1 && tx[i]<=a2 && ty[i]>=b1 && ty[i]<b2 ){  //Case 3
                    S = tx[i]*(b2-b1)/(a2-a1) + b_3; // a2＝a1 にはならない
                    if (ty[i] > S ) {//printf("break Tr-No.=%d \n",m);
                        break;}
                }
                if ( tx[i]>=a2 && tx[i]<a3 && ty[i]>=b3 && ty[i]<b2 ){  //Case 4
                    S = tx[i]*(b2-b3)/(a2-a3) + b_4;
                    if (ty[i] > S )  {//printf("break Tr-No.=%d \n",m);
                        break;}
                }
                if ( tx[i]>=a0 && tx[i]<a3 && ty[i]>b0 && ty[i]<=b3 ){ //Case 5
                    S = tx[i]*(b3-b0)/(a3-a0) + b_5;
                    if (ty[i] < S ) {//printf("break Tr-No.=%d \n",m);
                        break;}
                }

                idx++;
            }
//printf("TR-shori-END No.=%d \n",m);
            if (idx==3){ //３角形がこの４角形にふくまれる
                //  printf("SQ-TR OK = %d %d \n",n,m);
                ////////////////////////////ここまでＯＫ
                /////////////////////////////////////////

                ///////////////////////////////////////////////////////////////////////////////////////////////
                ///////// 以降　1-15 追加 三角が四角のどの角に近いか判定して射影する必要あり 1-15
                long ll[4];// ４角形の頂点と３角形の１点との距離（２乗)
                int ii;
                for(ii=0;ii<4;ii++)
                    ll[ii] =  (ax[ii]-tx[0])*(ax[ii]-tx[0]) + (bx[ii]-ty[0])*(bx[ii]-ty[0]);
                ii=minl_return(ll);
                //ax[ii]が射影後　左上の頂点になる
                //printf("  AX BX = %d %d ",ax[ii],bx[ii]);
                ////////////// 左上の頂点に最も近い三角形の頂点を探す　直角点　ij
                int ij;
                int ttx[3],tty[3];

                for(int ij=0;ij<3;ij++)
                    ll[ij] =(ax[ii]-tx[ij])*(ax[ii]-tx[ij]) + (bx[ii]-ty[ij])*(bx[ii]-ty[ij]);
                ij = minl_return(ll);
                if (ll[ij]  < TRmin*0.5) { printf("TRmin Wrong \n");continue;}//四角点と三角直角点が近すぎる時エラー
                // *0.5 は意味不明？検討要す２０１９－６－３０
                ////////////////////////////////
                //////////並べ替え　右か左か不明なので　右回りにする////////////////////////////////////
                //printf("\ntx0 ty0 =%d %d  tx1 ty1= %d %d tx2 ty2= %d %d \n",tx[0],ty[0],tx[1],ty[1],tx[2],ty[2]);
                B=0;//外積の面積での＋－判断　Ａ＜０なら左回り
                for (int i=0;i<3;i++)
                { Ba[i]=tx[i]*ty[(i+1)%3] - tx[(i+1)%3]*ty[i];
                    B = B+Ba[i];
                }
                //printf("B=%f",B);
                if (B<0)
                {
                    ttx[0]=tx[ij];
                    tty[0]=ty[ij];
                    ttx[1]=tx[(ij+2)%3];
                    tty[1]=ty[(ij+2)%3];
                    ttx[2]=tx[(ij+1)%3];
                    tty[2]=ty[(ij+1)%3];
                }
                else{
                    ttx[0]=tx[ij];
                    tty[0]=ty[ij];
                    ttx[1]=tx[(ij+1)%3];
                    tty[1]=ty[(ij+1)%3];
                    ttx[2]=tx[(ij+2)%3];
                    tty[2]=ty[(ij+2)%3];
                }

                /////////////////////////　ii は角度情報ではない///////
                // 0(-45-45) 1(-45-135) 2(-135- 135) 3(135-45)左周り
                angl=-1;// 判断できない時追加　境界の時　幅を持たせる必要あり
                ///// 以下　アングルの新しいルーチン　２０１９－２－２５
                //long LL[4];
                int p=ii;

                if (ax[0] < ax[2]){
                    if (p==0) angl=0;
                    if (p==1) angl=3;
                    if (p==2) angl=2;
                    if (p==3) angl=1;
                }
                else if (ax[0] > ax[2]){
                    if (p==0) angl=3;
                    if (p==1) angl=2;
                    if (p==2) angl=1;
                    if (p==3) angl=0;
                }

                if (angl < 0) //break;//
                    continue;
                /////////////////////////////////////////////
                /////////////////////////// 射影部分　ｈは変換行列
                vector<Point2f> pts_src;
                vector<Point2f> pts_dst;
                // Four corners of source image
                pts_src.push_back(Point2f(ax[ii], bx[ii]));// 上から右周りの座標
                pts_src.push_back(Point2f(ax[(ii+1)%4], bx[(ii+1)%4]));
                pts_src.push_back(Point2f(ax[(ii+2)%4], bx[(ii+2)%4]));
                pts_src.push_back(Point2f(ax[(ii+3)%4], bx[(ii+3)%4]));

                pts_dst.push_back(Point2f(0, 0));
                pts_dst.push_back(Point2f(250, 0));
                pts_dst.push_back(Point2f(250, 250));
                pts_dst.push_back(Point2f(0, 250));

                Mat h = findHomography(pts_src, pts_dst);

                double dataB[3];
                double xx,yy;
                Mat s_1(3, 1, CV_64FC1);
                Mat point0 = Mat(3, 1, CV_64FC1);
                int gx[3],gy[3];

                for(int i=0;i<3;i++){
                    //point0.at<double>(0,0) = tx[(ij+i)%3];// 三角形の直角点の射影tx[ij],ty[ij] その他も射影
                    //point0.at<double>(1,0) = ty[(ij+i)%3];
                    //point0.at<double>(2,0) = 1;
                    point0.at<double>(0,0) = ttx[i];// 三角形の直角点の射影ttx[0],tty[0] その他も射影
                    point0.at<double>(1,0) = tty[i];
                    point0.at<double>(2,0) = 1;

                    s_1 = h*point0;// 射影　ｘ’＝ｈ＊ｘ　本来ならdataB[0]/dataB[2],dataB[1]/dataB[2]とする

                    dataB[0]=s_1.at<double>(0,0);
                    dataB[1]=s_1.at<double>(1,0);
                    dataB[2]=s_1.at<double>(2,0);
                    xx = dataB[0]/dataB[2];
                    yy = dataB[1]/dataB[2];
                    gx[i]=xx;
                    gy[i]=yy;
                }

                //printf("gx0 gy0= %d %d  gx1 gy1= %d %d  gx2 gy2= %d %d",gx[0],gy[0],gx[1],gy[1],gx[2],gy[2]);
////////////////////////////////////////////////////
////////////////////////////////////////////////////
        int LR=1;////////////////////// この部分に三角形のLRの判断////////x座標で下の頂点が上辺の中点より小さければ右向き////
        if((gx[1]+gx[0]) > 2*gx[2]) LR=0;// left
/////////////////////////////////////////////////////////////
        if(LR==0){
// 以下は　理論的には　gx,gy = 25,42
            if ((gx[0]<15)||(gx[0]>40)||(gy[0]<25)||(gy[0]>60)){//////直角点範囲　ここではじかれることが多い
    //　斜め画像で三角形が奥の場合のgyに対して gy を変更したがgy<20 はありえない　元に戻す　2019-2-12
            //if ((gx<15)||(gx>35)||(gy<25)||(gy>50)){/////// gx15 なら gy32 が正しい
              continue;//射影点が範囲内にない時
            }
//////////////////////////以下　三角形のチェック　その他　追加必要？
            if( ( (gx[1]-gx[0]) > 55 ) || ( (gx[1]-gx[0]) < 30) ) continue;// X方向　５０まで
            if( ( (gy[2]-gy[0]) > 20 ) || ( (gy[2]-gy[0]) < 10) ) continue;// Y方向　１７まで

            if(gy[0]<gy[1]){
              if( (gy[1]-gy[0]) > TRC ) continue;// gy[0]+-5 以内にgy[1]がない場合エラー
            }
            else if( (gy[0]-gy[1]) > TRC ) continue;

            if(gx[0]<gx[2]){
                if( (gx[2]-gx[0]) > TRC ) continue;// gx[0]+-5 以内にgx[2]がない場合エラー
            }
            else if( (gx[0]-gx[2]) > TRC ) continue;
          }
//////////////////////////////////////////////////////////////////////////
          if (LR == 1){
//if((gx[1]<65)||(gx[1]>80)||(gy[1]<25)||(gy[1]>50)){// 逆三角の直角点　座標 5✕5
//if((gx[1]<57)||(gx[1]>68)||(gy[1]<30)||(gy[1]>45)){// 逆三角の直角点　座標 6✕6 三角小
              if((gx[1]<40)||(gx[1]>53)||(gy[1]<30)||(gy[1]>45)){// 逆三角の直角点　座標 6✕6　三角20✕40 (48,38)*****************
                printf("homo TR1-ERR gx gy =%d %d \n",gx[1],gy[1]);
              continue;
          }

//if( ( (gx[1]-gx[0]) > 55 ) || ( (gx[1]-gx[0]) < 30) ) continue;// X方向　５０まで 5✕5
//if( ( (gy[2]-gy[1]) > 20 ) || ( (gy[2]-gy[1]) < 10) ) continue;// Y方向　１７まで 5✕5
//if( ( (gx[1]-gx[0]) > 45 ) || ( (gx[1]-gx[0]) < 25) ) {// length (50mm)
          if( ( (gx[1]-gx[0]) > 42 ) || ( (gx[1]-gx[0]) < 20) ) {// length 33.3(40mm✕5%6)  X方向　33まで    42---->39
              printf("homo TR1-ERR2 gx0 gx1 =%d %d \n",gx[0],gx[1]);
              continue;// X方向　6✕6
          }
//if( ( (gy[2]-gy[1]) > 15 ) || ( (gy[2]-gy[1]) < 7) ) {
          if( ( (gy[2]-gy[1]) > 20 ) || ( (gy[2]-gy[1]) < 10) ) {//Y方向　16.7
              printf("homo TR1-ERR3 gy1 gy2 =%d %d \n",gy[1],gy[2]);
              continue;//
          }
          if(gy[0]<gy[1]){
            if( (gy[1]-gy[0]) > TRC ) continue;// gy[1]+-5 以内にgy[0]がない場合エラー
            }
          else if( (gy[0]-gy[1]) > TRC ) continue;

          if(gx[1]<gx[2]){
            if( (gx[2]-gx[1]) > TRC ) continue;// gx[1]+-5 以内にgx[2]がない場合エラー
          }
          else if( (gx[1]-gx[2]) > TRC ) continue;
        }
////////////
//////////////////////////////////////////////////////////////////

                polylines(image, sq[n], true, Scalar(0,255, 0), 2);

                Mat im_out;
                warpPerspective(image, im_out, h, cv::Size(250, 250));


                int invmean=0;
                
                //2025/12/20 検証
                long tempCode = Getcode(im_out,gx,gy,invmean,LR);
                if (tempCode > 0) {
                    // 成功：青色
                    polylines(image, sq[n], true, Scalar(255, 0, 0), 3);
                } else if (tempCode == -2) {
                    // 三角形が見つからないエラー：黄色
                    // (変形後の画像の中で▲の位置が特定できていません)
                    polylines(image, sq[n], true, Scalar(0, 255, 255), 3);
                } else if (tempCode == -3) {
                    // 点のカウントエラー：紫色 (Scalarは B, G, R なので 255, 0, 255)
                    // (▲は見つかったが、点の白黒判定に失敗しています)
                    polylines(image, sq[n], true, Scalar(255, 0, 255), 3);
                } else {
                    // その他のエラー：白色
                    polylines(image, sq[n], true, Scalar(255, 255, 255), 3);
                }
                
                
                
                code[cindex] = Getcode(im_out,gx,gy,invmean,LR);// 三角形の直角頂点を使うかは検討要す
                invmeanf=invmean;
                if (code[cindex] > 0){
                    tmx[cindex] = m;// m番目の３角形を記録
                    Angle[cindex] = angl;
                    cindex++;

                    flag=1;// 2019-6-24 追加　同じ４角形で次の三角形の処理をやめる
                    //break;// 次の４角形
                }
                ////////////////////////////////// 射影ＯＫ
            }// if index==3.........
            if (flag == 1) { flag=0; break; }// 追加　2019-6-24 次の四角形へ
        }// Tr for文　３角形包含チェック

    }// SQ for文
///////////////////////////////////////////////////////
//////////// コードの重複チェック　　バグあるかも　3-18
///// コードが２種類以上で重複があった場合はどうするか　追加チェック必要　4-2
    int cnt=0;
    Code=0;
    if (cindex==0) return -1;
    if (cindex==1) {
        //printf("Single1-code=%ld Angle=%d \n",code[0],angl);//test
        //PlaySound("trurun.wav",NULL,SND_FILENAME | SND_SYNC);
        Code=code[0];
        Angl=Angle[0];
        return 0;
    }
    ////////// cindex が１の時は少ない　同じコードがいくつもあるので

    if ((cindex > 1)&&(cindex < 7)){  //////////////////////////same code check <20 訂正　２０１９－３－１２
        for(int j = 0; j < cindex; j++){ //訂正。重複する数字を左から見ていく
            //cnt = 0;
            for(int k = j+1; k < cindex; k++){ //見ていく数字
                if((code[j] && code[j] == code[k])&&(tmx[j] == tmx[k]))
                    code[k] = 0;
                if((code[j] && code[j] == code[k])&&(tmx[j] != tmx[k])&&(Angle[j] == Angle[k])){ //
                    cnt++; //追加。アングルのチェック
                    code[k] = 0; //追加。cntチェック済み
                }
            }

            if(cnt){ //重複があったら
                Code=code[j];
                Angl=Angle[j];
                //printf("                      Same Code=%ld Angle=%d\n ",Code,Angl);
                return 1;
            }
        }
        Code=code[0];
        Angl=Angle[0];
        return 0;
    }
    return -1;    ////////////////////////////////
}


static double a_angle(cv::Point pt1, cv::Point pt2, cv::Point pt0 )
{
    double dx1 = pt1.x - pt0.x;

    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}


//////////////////////////////////////４角形の形をチェック//////////////////////
static int sqch(vector<cv::Point>& ap )
{
    int x[4];
    int y[4];
    double m[4];
    double min,max;
    int idx;
    for (int i=0; i<4; i++){
        x[i]=(int)ap[i].x;// ax 右回りかどうか不明
        y[i]=(int)ap[i].y;
    }

    m[0]=(x[0]-x[1])*(x[0]-x[1]) + (y[0]-y[1])* (y[0]-y[1]);
    m[1]=(x[1]-x[2])*(x[1]-x[2]) + (y[1]-y[2])* (y[1]-y[2]);
    m[2]=(x[2]-x[3])*(x[2]-x[3]) + (y[2]-y[3])* (y[2]-y[3]);
    m[3]=(x[3]-x[1])*(x[3]-x[1]) + (y[3]-y[1])* (y[3]-y[1]);
    idx = mind_return(m);
    min = m[idx];
    idx = maxd_return(m);
    max = m[idx];

    if (max < min*4) return 0;
    return -1;
}




//MARK: -- ５角形の最短辺を探す そのあと交点を見つけて４角形にする
static int Get_quad( vector<cv::Point>& penta, vector<cv::Point>& sq)
{
    int i,j;
    int x,y;
    int px[5],py[5];
    long ll[5];// 5角形の辺の長さ（２乗）

    for (i=0; i < 5; i++){// penta 5個
        px[i]=(int)penta[i].x;// 右回り?????チェック必要
        py[i]=(int)penta[i].y;
    }
    //  2-21　苦労　これを一緒にやろうとしたのが間違い　i+1には値が入っていないため
    for (i=0; i < 5; i++){
        ll[i] = (px[i]-px[(i+1)%5])*(px[i]-px[(i+1)%5]) + (py[i]-py[(i+1)%5])*(py[i]-py[(i+1)%5]);
    }
    j = mind_return(ll);// 最短辺　a-c
    //std::cout << penta;
    ////// ５角形の延長線から交点を見つける////doble 必要1-22 /////////////
    double ax=px[j],        ay=py[j];// axは右回り
    double bx=px[(j+4)%5],  by=py[(j+4)%5];
    double cx=px[(j+1)%5],  cy=py[(j+1)%5];
    double dx=px[(j+2)%5],  dy=py[(j+2)%5];

    double s1=( (dx-cx)*(ay-cy)-(dy-cy)*(ax-cx) )/2;
    double s2=( (dx-cx)*(cy-by)-(dy-cy)*(cx-bx) )/2;
    double zx=ax+(bx-ax)*s1/(s1+s2);
    double zy=ay+(by-ay)*s1/(s1+s2);
    x=zx;
    y=zy;

    for (i=0; i<5; i++)
        if (i==j){
            sq.push_back(cv::Point(x, y));
            i++;
        }
        else
            sq.push_back(cv::Point(penta[i].x, penta[i].y));
    return j;
}



static int min_return(int *a)
{
    int min,idx;
    min = a[0]; idx = 0;
    for (int j=0; j<4; j++){ if(a[j] < min){  min = a[j];idx = j;}}
    return idx;
}


int maxtd_return(double *a)
{
    double max;
    int idx;
    max = a[0]; idx = 0;
    for (int j=0; j<3; j++){  if(a[j] > max){  max = a[j]; idx = j;}  }
    return idx;
}

int max_return(int *a)
{
    int max,idx;
    max = a[0]; idx = 0;
    for (int j=0; j<4; j++){  if(a[j] > max){  max = a[j]; idx = j;}  }
    return idx;
}


static int mind_return(double *a)
{
    double min;
    int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<4; j++){ if(a[j] < min){  min = a[j];idx = j;}}
    return idx;
}


static int mind_return(long *a)
{ long min;
    int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<5; j++){ if(a[j] < min){  min = a[j]; idx = j;}}
    return idx;
}


int maxd_return(double *a)
{
    double max;
    int idx;
    max = a[0]; idx = 0;
    for (int j=0; j<4; j++){  if(a[j] > max){  max = a[j]; idx = j;}  }
    return idx;
}


static int mintd_return(double *a)
{
    double min;
    int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<3; j++){ if(a[j] < min){  min = a[j];idx = j;}}
    return idx;
}


static int minl_return(long *a)
{ long min;
    int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<4; j++){ if(a[j] < min){  min = a[j]; idx = j;}}
    return idx;
}


// MARK: -- ３角形の直角頂点を使ったコード取得  ３角形の白黒判定
static long Getcode( const Mat& image, int *X, int *Y,int &invmean, int LR)
{
    int black[5][5];

    unsigned char B[25];
    int xx=0;
    int yy=0;
    int max;

    Mat img = image.clone();
    Mat img0,img1,mt,gray,gray1,pyr;
    Mat yellow=Mat(img.size(),CV_8UC3);
    Mat ygray,ygray0,ygray6,ygray1;
    Mat mask = Mat::zeros(img.rows, img.cols, CV_8UC1);
    vector<Mat> plane,pl0;
    vector<Mat> plane1;
/////////////////look-up-table
    double gamma = 1.8;                                    // ガンマ値
    Mat lookUp(1,256,CV_8U);
    uchar*  lut = lookUp.data;                                    // ルックアップテーブル用配列
    for (int i = 0; i < 256; i++) {
        lut[i] = pow(i / 255.0, 1 / gamma) * 255.0;        // ガンマ補正式
    }
    //cv::LUT(src, cv::Mat(1, 256, CV_8UC1, lut), dst2);    // ルックアップテーブル変換
//////////////////////////////////
    int invmean0;

    medianBlur(img,img1,5);
    cvtColor(img1, gray1, COLOR_BGR2GRAY);
    //imshow("Getcode-gray",gray1);
    //invmean=mean(gray1)[0];
    //////TEST 2019-12-26 ////////////////////////////
    int Tx = (X[0] + X[1] + X[2])/3;// 三角内部が黒か白かチェック
    int Ty = (Y[0] + Y[1] + Y[2])/3;
    int b=0;
    int w=0;
    for (int y=Ty-1; y<Ty+2; y++)// このエリアが黒ならＯＫ　重心のまわり９ピクセル
        for (int x=Tx-1; x<Tx+2; x++)
        {
            int color0 = gray1.at<unsigned char>(y,x);
            if (color0 < 200) //黒チェック
                b++;
            else  w++;
        }

    split(img, plane);
    pl0.push_back(mask);//黒
    pl0.push_back(plane[1]);//G
    pl0.push_back(plane[2]);//R
    merge(pl0,yellow);
    cvtColor(yellow,gray, COLOR_BGR2GRAY);

    if (b<w){// White TR
        bitwise_not(gray,gray);
        invmean=mean(gray)[0];
    }
    ////////////////////////////////////////////////////
    //////// 三角形直角点 座標
    int ret = GfindTr1(gray,xx,yy,LR);
    
    //2025/12/20 検証
    if(ret < 1) return -2; // ★変更: 三角形が見つからない場合は -2
    //if(ret < 1) return -1;
    //{ xx=X[0]; yy=Y[0];}// xx yy がとれない場合　旧来の座標使用　・・・return -1 でもよいかも
    //////////////////////////////////////////////
    pyrDown(gray, pyr, cv::Size(image.cols/2, image.rows/2));
    pyrUp(pyr, ygray, image.size());//ある程度影がなくなる　　ぼやけるが
    medianBlur(ygray,ygray0,7);
    if(b>w){
        adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,37);// Black 41,37
        //imshow("Black-code-data41-37",mt);
    }
    else{
        if(invmean < 90){
            LUT(ygray0,lookUp,ygray0);
            invmean0=mean(ygray0)[0];
            //adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);//for White TR 41,21
            //adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,67,35);
        }

        adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,67,35);//BEST
    }
    //////////////////////////////////////
    if(LR==0){
          Black_point0(mt,black);
          //printf("\n 7: Black-point055");
          }
      if(LR==1){
          //printf("\n 7: Black-point066\n");
          Black_point(mt,black);// ここで6✕6ブロックに対応
          }
    //Black_point(mt,black,xx,yy);

    max = 0;
    black[0][0]=0;  black[0][1]=0;  black[1][0]=0;  // 一番左とその隣、その下は使わない
    for (int j=0; j<5; j++)
        for(int i=0; i<5; i++){
            if (black[j][i] > max)  max = black[j][i];
        }

////////////////////////////////////////////////////////
    //if ((max < 150) || (max > 350)) return -1;/// max < 450 は大きすぎ?? 2019-2-18
    //if ((max < 120) || (max > 450)) return -1;/// min 150 はちいさい　350から380へ変更　2019-11-4
    
    //2025/12/20 検証
    if ((max < 120) || (max > MaxblackPiont)) return -3; // ★変更: 点のカウント失敗は -3
    //if ((max < 120) || (max > MaxblackPiont)) return -1;/// min 150 はちいさい　450から600へ変更　2020-8
    
//////////////////////////////////以下　黒点数により　０か１に変換/////////////////////
    for ( int j=0; j<5; j++)
        for (int k=0; k<5; k++)
            //if ( (black[j][k] > ( max - 100)) && (black[j][k] > 120) ) B[5*j+k]=0x31;//or---- >  && バグ　2019-12-14
            if ( (black[j][k] < MaxblackPiont) && (black[j][k] > 120) ) B[5*j+k]=0x31;//or---- >  && バグ　2019-12-14 ///max-200---->-250 12-26
            else B[5*j+k]=0x30;// -100 は適当


    B[0]=0x30;//一番左上は使わない　取りあえず　　三角マーカーの黒を拾うため
    if(LR==0) {
      B[1]=0x30;// ２番目も使わない　１２－２５
      B[5]=0x30;// ２列目左も使わない　２０１８－５－２２
    }
    ///////////////////////////////////////////////////////////
    long val=0;
    for ( int j=0; j<25; j++){
        //printf("B[j]=%2x ",B[j]);
        switch (B[j]){
            case '0':
                val *= 2;
                break;
            case '1':
                val = val * 2 + 1;
                break;
        }
    }
    //2025/12/20 検証
    //if (val==0) return -1;
    if (val==0) return -3;
    
    
    return val;
}


static int minl_return3(long *a) { // 3回ループ版
    long min; int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<3; j++){ // ここを3にする
        if(a[j] < min){ min = a[j]; idx = j; }
    }
    return idx;
}
// 2025/12/22 修正
// MARK: -- FindTR for Get_Code
///////////////////////////New GfindTr1/////add 6*6//////////2022
static int GfindTr1( const Mat& gray, int &X, int &Y, int LR )
{  vector<vector<cv::Point> > contours;
   vector<vector<cv::Point> > contours1;

    vector<cv::Point> approx;
    Mat element = getStructuringElement(MORPH_RECT, cv::Size(3,3));
    double area;
    Mat mt,mt0;
    //Mat img1 = image.clone();
    //Mat gray(image.size(), CV_8U);
    Mat gray0;
    //Mat grayw(image.size(), CV_8U);
    long ll[3];
    int ij;
    ////////////////////////////////////////////////
    // Rect rect(X, Y, xl, yl);
      cv::Rect rect(10,20,80,80);//三角形の場所 X,Yは直角点
      Mat imgSub(gray, rect);
      //imshow("imgSub", imgSub);

//////////////////////////Canny
      Canny( imgSub, gray0, 60, 180,3 );
        //imshow("FT-Canny",gray0);
      morphologyEx(gray0,mt0,MORPH_CLOSE,element, cv::Point(-1,-1),1);// 三角頂点がつながらないケースあり必要2019-12-29
        //imshow("Mor-TRCanny",mt0);

        findContours(mt0, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);

        int t=0;              // 三角形個数

      for( size_t i = 0; i < contours.size(); i++ )
      {
          if (t > 3) break;
          area = contourArea(contours[i]);
          //if (area > 300 && area < 600){   //三角画像サイズ　416.7
          if (area > 200 && area < 600){   //三角画像サイズ変更　6✕6の三角は小さい為
            // 直線近似
          //  approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.05, true);//0.05
          approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.05, true);
            // 2025/9/4
              if (approx.size() == 3 && t < 4) {
                  t++;
                  
                  // approxが空またはサイズが3未満の場合に備える
                  // このif文は、直前の if (approx.size() == 3 ... ) で既にチェック済みなので、
                  // ここに重複して置く必要はありません。
                  // もし、このコードブロックが別の関数であれば、このガード句は有効です。
                  
                  // ll ベクターの型をlongに変更し、サイズを事前に確保
                  std::vector<long> ll(3);

                  if (LR == 0) {
                      for(int j = 0; j < 3; j++) {
                          ll[j] = (long)approx[j].x * (long)approx[j].x + (long)approx[j].y * (long)approx[j].y;
                      }
                      ij = minl_return3(ll.data());

                      // ijが有効なインデックスであることを確認
                      if (ij >= 0 && ij < approx.size()) {
                          X = (int)approx[ij].x + 10;
                          Y = (int)approx[ij].y + 20;
                          //printf( "\n Canny TR-R X=%d Y=%d \n", X,Y );
                          return 1;
                      }
                  }

                  if (LR == 1) { // 三角左向き
                      for(int j = 0; j < 3; j++) {
                          ll[j] = (80 - (long)approx[j].x) * (80 - (long)approx[j].x) + (long)approx[j].y * (long)approx[j].y;
                      }
                      ij = minl_return3(ll.data());

                      // ijが有効なインデックスであることを確認
                      if (ij >= 0 && ij < approx.size()) {
                          X = (int)approx[ij].x + 10;
                          Y = (int)approx[ij].y + 20;
                          //printf( "\n Canny TR-L X=%d Y=%d \n", X,Y );
                          return 1;
                      }
                  }
            }
          }
        }
      //////////////////
      if(t==0){
        //adaptiveThreshold(gray,mt1,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,67,35);// 通常の黒三角はこれでOK　従来どおり
          adaptiveThreshold(imgSub,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,67,35);
        //imshow("FT-Adap", mt1);
        //adaptiveThreshold(imgsub,mt1,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,15);//白三角はこちらの方がよいかも？
        //imshow("TR-White-41-15", mt1);
          findContours(mt, contours1, RETR_LIST, CHAIN_APPROX_SIMPLE);
          for( size_t i = 0; i < contours1.size(); i++ )
          {
            if (t > 3) break;
            area = contourArea(contours1[i]);
            //if (area > 300 && area < 600){   //画像サイズ640の時100　1000なら200
              
            // 2025/9/5 修正
              if (area > 200 && area < 600) {
                  // approxPolyDP(Mat(contours1[i]), approx, arcLength(Mat(contours1[i]), true)*0.05, true);
                  approxPolyDP(Mat(contours1[i]), approx, arcLength(Mat(contours1[i]), true) * 0.05, true);

                  if (approx.size() == 3 && t < 4) {
                      t++;

                      // approxのサイズが3であることを確認
                      // 既に外側のif文でチェックしているため、この部分は不要ですが、
                      // 念のため、安全なアクセスを保証するロジックを再構成します。
                      if (approx.size() < 3) {
                          // サイズが3未満の場合は何もしない
                          // この場合、案内表示ロジックは実行されないが、エラーは発生しない
                          // returnは関数全体を終了させるため、ここでは使わない
                      } else {
                          // approxのサイズが3であることを確認してから処理
                          std::vector<long> ll(3);

                          if (LR == 0) {
                              for (int j = 0; j < 3; j++) {
                                  ll[j] = (long)approx[j].x * (long)approx[j].x + (long)approx[j].y * (long)approx[j].y;
                              }
                              ij = minl_return3(ll.data());
                              
                              // ijが有効なインデックスであることを確認
                              if (ij >= 0 && ij < approx.size()) {
                                  X = (int)approx[ij].x + 10;
                                  Y = (int)approx[ij].y + 20;
                                  return 1;
                                  // printf( "\n Canny TR-R X=%d Y=%d \n", X,Y );
                              } else {
                                  // 無効なインデックスの場合は何もしない
                              }
                          }

                          if (LR == 1) { // 三角左向き
                              for (int j = 0; j < 3; j++) {
                                  ll[j] = (80 - (long)approx[j].x) * (80 - (long)approx[j].x) + (long)approx[j].y * (long)approx[j].y;
                              }
                              ij = minl_return3(ll.data());

                              // ijが有効なインデックスであることを確認
                              if (ij >= 0 && ij < approx.size()) {
                                  X = (int)approx[ij].x + 10;
                                  Y = (int)approx[ij].y + 20;
                                  return 1;
                                  // printf( "\n Canny TR-L X=%d Y=%d \n", X,Y );
                              } else {
                                  // 無効なインデックスの場合は何もしない
                              }
                          }
                      }

              }
            }
        }
      }


    if (t == 0)  return -1;
  return 0;
}

////////////////////
///////////////////////////////　6✕6ブロック　２５個の突起の黒点数算出/////Get_codeよりcall
static void Black_point(const Mat& mt, int black[5][5])
{
    int x,y,x0,y0;
    //////////////////// 周囲の枠を塗りつぶし/////// これは効果的　////////////////////
    // Red，太さ3，4近傍連結
    rectangle(mt, cv::Point(0,0), cv::Point(250, 250), Scalar(0,0,0), 5, 4);
      //imshow("Rectangle-RRR",mt);
    for(  int j = 0; j < 5; j++ )
        for( int k = 0; k < 5; k++)
          {
            x0 = 42*k + 42;// 50*5%6 300--->250の為　41.6
            y0 = 42*j + 42;
            ///////////////////////
            int XL=15,XR=15,YU=15,YD=15;// 30✕30の範囲でカウント
            // エリア外参照チェックは省く
            ////////////////////////
            black[j][k]=0;
          /////////////////////////////////////////////////////////////////
            for (y=y0-YU; y<y0+YD; y++)
              for (x=x0-XL; x<x0+XR; x++)
                {
                  int color0 = mt.at<unsigned char>(y,x);// このｘ、ｙがエリア外参照？
                  if (color0 > 200) //黒カウント 実際は反転なので白をカウント ２００
                    black[j][k]++;
                }
          }
  //////////////////////////////////////// ここまでは通常　////////////
  ////////////// 以下　一様に影がある場合　真ん中をリファレンスにする試行
      int ref = black[2][2];
    if((ref > 85)&&(ref < 400)){//70だとオリジナルでとれるものもエラーになる場合あり
      //100前後は突起内の影　西日などによる突起をはみ出した突起の本体の影は180を超えるケースあり
        for (int i=0;i<5;i++){
              //  printf(" \n");
                  for(int j=0;j<5;j++){
                    black[i][j]=black[i][j]-ref;
                    if (black[i][j]<0) black[i][j]=0;
                    //printf(" %3d ",black[i][j]);//// -ref 2019-12-26
                  }
            }
      }
      ///////////////////////////////////
}
// MARK: -- ２５個の突起の黒点数算出/////Get_codeよりcall
static void Black_point0(const Mat& mt, int black[5][5])
{
    int x,y,x0,y0;
    //////////////////// 周囲の枠を塗りつぶし/////// これは効果的　////////////////////
    // Red，太さ3，4近傍連結
    rectangle(mt, cv::Point(0,0), cv::Point(250, 250), Scalar(0,0,0), 5, 4);
    //imshow("Rectangle-0",mt);

    for(  int j = 0; j < 5; j++ )
        for( int k = 0; k < 5; k++)
        {
            x0 = 50*k;
            y0 = 50*j;
            ////////////////////////
            black[j][k]=0;
            /////////////////////////////////////////////////////////////////
            for (y=y0; y<y0+50; y++)
                for (x=x0; x<x0+50; x++)
                {
                    int color0 = mt.at<unsigned char>(y,x);
                    if (color0 > 200) //黒カウント 実際は反転なので白をカウント ２００
                        black[j][k]++;
                }
        }
    //////////////////////////////////////// ここまでは通常　////////////
    ////////////// 以下　一様に影がある場合　真ん中をリファレンスにする試行
    int ref = black[2][2];
    if((ref > 85)&&(ref < 400)){//70だとオリジナルでとれるものもエラーになる場合あり
        //100前後は突起内の影　西日などによる突起をはみ出した突起の本体の影は180を超えるケースあり
        for (int i=0;i<5;i++){//print only
            //printf(" \n");
            for(int j=0;j<5;j++){
                //int bll=black[i][j]-black[2][2];
                //if (bll<0) bll=0;
                //printf(" %3d ",bll);//// -ref 2019-12-26
                black[i][j]=black[i][j]-ref;
                if (black[i][j]<0) black[i][j]=0;
                //printf(" %3d ",black[i][j]);//// -ref 2019-12-26
            }
        }
    }
}
@end
