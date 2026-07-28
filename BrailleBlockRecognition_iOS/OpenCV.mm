// 2025-9-28 test版
// 2022-5-26　受信（旧）
// cv::が必要
#import <opencv2/opencv.hpp>
#import <opencv2/core.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgcodecs/ios.h>

#import "OpenCV.h" //ライブラリによってはNOマクロがバッティングするので，これは最後にimport
#include <opencv2/core/version.hpp>


#include <string>
#include <vector>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>


using namespace std;
using namespace cv;

const double MCosine = 0.7; // 0.7   0.3 低い角度からの画像では四角の角度が鋭角になる 0.4
const int SQmin = 10000;
const int SQsmall = 20000;

//const int SQmax = 170000;//ele 100000 135000------> 100000 ----->150000 andoroid Pixel XL---->170000
const int TRmin = 50;//log=200 el=120// 2018-10-26 変更テスト　120---> 100--->80  2019-2-7 変更　７０（６０でもいける） 80---->android Pixel XL
const int TRmax = 1000;//Log=900(1m) el=800// 2018-10-26 変更テスト900-->600-----//2020-1-14 700--->900
const int MaxblackPoint = 1500;
const int MinblackPoint = 150;// 250では120
const int CheckBW = 200; // Gray 画像の白黒チェック値

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
    int twindex =0;
    int trindex = 0;
    int trwindex = 0;///////追加　2023-10-7
    int sindex = 0;
    int sqindex = 0;
    int sqaindex = 0;

    vector<vector<cv::Point> > tr;// 三角形　エリア 座標 個数オーバーか？　２０－－－＞４０へ 原因不明エラーでストップ　9/14
    //tr.resize(20);
    tr.clear();
    vector<vector<cv::Point> > trw;//白三角用　追加2023-10-7
    //trw.resize(20);
    trw.clear();

    vector<vector<cv::Point> > Tr;// 三角形　エリア 座標 // = vector<Point> tr[10];
    //Tr.resize(20);
    Tr.clear();
    vector<vector<cv::Point> > Trw;// 三角形　エリア 座標 // = vector<Point> tr[10];
    //Trw.resize(20);
    Trw.clear();

    vector<vector<cv::Point> > Sq;// ４角形　エリア 座標 Canny
    //Sq.resize(20);
    Sq.clear();
    vector<vector<cv::Point> > Sqa;// ４角形　エリア 座標 Adaptive
    //Sqa.resize(20);
    Sqa.clear();
    vector<vector<cv::Point> > sq;// ４角形　エリア 座標 duplicate check
    //sq.resize(40);
    sq.clear();

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


    //int invmean=mean(image)[0];

    sqaindex = mask(image, img1, img2, Sqa);
    sindex = findSq(image, img2, Sq);//orignal+ yellow-maskでの抽出　sindex;４角形個数
    if ((sindex + sqaindex) != 0)
        //sqindex = Sqcheck(Sq, sindex, Sqa, sqaindex, sq);
        sqindex = Sqcheck(Sqa, sqaindex, Sq, sindex, sq );
        // チェック順変更　sq sqa  2025-6-17

    if (sqindex != 0) {//四角形があった場合のみ三角形をその内部で探す
        int maskmean;
        Trmask(image, sq, sqindex, img3, img4, maskmean);//img3 black, img4 white-Tr
        //tindex = findTr(img3, img4, Tr);

        int ret0 = findTr(img3, img4, Tr, tindex, Trw, twindex, maskmean);
          //printf("     Tr=%d Trw=%d \n",tindex,twindex);
        //if (ret0==0) continue;
    }
    /////////////////////////////////
    /////////////////////////////////
        Code = 0;
        Angl = -1;

        int ret = -1;
        int retw = -1;

        // 1. まず黒三角（TrBW = 0）をチェックする
        if (tindex != 0){
            trindex = Trcheck(Tr, tindex, tr);
            ret = FHomo(image, sq, sqindex, tr, trindex, 0);
            
            if (ret == 0) { // 1個のみ 例外処理
                if ((Code >= 5242880) && (Code < 6291456)) {
                    ret = 1;
                }
            }
        }

        // 2. 黒三角でコードが取れなかった場合のみ、白三角（TrBW = 1）をチェックする
        // （無駄な処理を省き、グローバル変数Codeの上書きを防ぐ）
        if (ret < 0 && twindex != 0){
            trwindex = Trcheck(Trw, twindex, trw);
            retw = FHomo(image, sq, sqindex, trw, trwindex, 1);
            
            if (retw == 0) { // 1個のみ 例外処理
                if ((Code >= 5242880) && (Code < 6291456)) {
                    retw = 1;
                }
            }
        }

        // 3. 黒三角でも白三角でも有効なコードが取れなかった場合のみ、結果をリセット
        if (ret < 0 && retw < 0){
            Code = 0;
            Angl = -1;
        }

        cv::cvtColor(image, image0, COLOR_BGR2RGBA);
        /////////////////////////////////////////////
    /////////////////////////////////////////////

//    Ret[0]=ret;
//    Ret[3]=invmean;//画像全体の輝度
//    Ret[4]=invmeanf;//Get_codeへの画像輝度
// 1:２個取れた時 0:１個取れた時
//        Ret[1] = Code;
//        Ret[2] = Angl;

    

    NSNumber *code_n = [NSNumber numberWithLong:Code];
    NSNumber *angle_n = [NSNumber numberWithInt:Angl];


    UIImage *resultImg = MatToUIImage(image0);
    NSArray *result = [NSArray arrayWithObjects:code_n,angle_n,resultImg,nil];

    //NSArray *result = [NSArray arrayWithObjects:code_n,angle_n,nil];
    return result;
}


// MARK: -- img1 入力画像　image mask後の返却画像 imageGR ４角形抽出用返却画像　背景黒　修正　6-4 adaptiveのみでマスク 4-30 Lab L でのＣａｎｎｙ追加

static int mask( const Mat& img1, const Mat& image, const Mat& imageGR ,vector<vector<cv::Point> >& sqa )// mask 画像取得
{
    if(img1.empty()) return -1;

    int hight = img1.rows;
    int width = img1.cols;
    int SQmaxf = hight*width/6;

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

    //medianBlur(img1,gray,3);// 2025-9-- 5 to 3　大事　5:だと影では穴があく
    medianBlur(img1,n0,5);// 変更2020/01/20　for andoroid
    //cvtColor(gray, gray1, COLOR_BGR2GRAY);
    cvtColor(n0, gray, COLOR_BGR2GRAY);

    equalizeHist(gray,gray1);

    adaptiveThreshold(gray1,nh,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,11,5);// orignal 下は暗い時はより良いが　影の場合は不明

    cvtColor(n0, nh2, COLOR_BGR2Lab);
    split(nh2, plane2);
    Canny(plane2[0], l_b, 60,180,3);//60 180
    bitwise_or(nh, l_b, nh);
    //morphologyEx(nh,gray,MORPH_CLOSE,element,cv::Point(-1,-1),1);
    findContours(nh, contours0, RETR_LIST, CHAIN_APPROX_SIMPLE);
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
        if (area >SQmin && area < SQmaxf){// 25000  95000
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
            if ((aps > 4 )&&(aps <= 20 )){// 20は適当　検討要する？
                //convexHull(approx, approx_con);
                convexHull(Mat(contours[k]), approx_con);
                area2 = contourArea(approx_con);
                if ((approx_con.size() == 4 ) && (area2 < SQmaxf)){
                    maxCosine = 0;
                    for( int j = 0; j < 4; j++ )
                    {
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    int check = sqch(approx_con);
                    if(( maxCosine < MCosine )&&(check == 0)){
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
                    if ((approx_con1.size() == 4 ) && (area2 < SQmaxf)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                            cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                            //if( maxCosine < MCosine ){
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

    for( size_t k = 0; k < contours0.size(); k++ )
    {
        if (s1 > 10) break;
        area = contourArea(contours0[k]);
        if (area >SQmin && area < SQmaxf){// 25000  95000
            approxPolyDP(Mat(contours0[k]), approx, arcLength(Mat(contours0[k]), true)*0.01, true);// 0.01
            aps = approx.size();

    //    printf("APS=%d ",aps);
              if (aps == 4 ){// 左右周りは不明6-13
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
                        // 右周りの座標?
                      drawContours(mask0,contours0,k,Scalar(255),FILLED);
                      s1++;s2++;
                  }
              }
              if ((aps > 4 )&&(aps <= 20 )){// 20は適当　検討要する？１０にしたらダメ？２－４
              //convexHull(approx, approx_con);
                  convexHull(Mat(contours0[k]), approx_con);
                  area2 = contourArea(approx_con);
                  if ((approx_con.size() == 4 ) && (area2 < SQmaxf)){
                    maxCosine = 0;
                    for( int j = 0; j < 4; j++ )
                        {
                            //cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                            cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                          }
                    int check = sqch(approx_con);
                    if(( maxCosine < MCosine )&&(check == 0)){
                    //  printf("Q2 \n");
                        // 新しいベクターを作成し、approx_conをコピー
                        std::vector<cv::Point> new_square = approx_con;
                        // sqaの末尾に新しい四角形を追加
                        sqa.push_back(new_square);

                        drawContours(mask0,contours0,k,Scalar(255),FILLED);
                      //sqa[s1].push_back(approx_con);// この部分不完全６－２１
                        s1++;s3++;
                        //polylines(img1, approx_con, true, Scalar(0, 0, 255), 2);//
                    }
                  }
                  if (approx_con.size() > 4 ){
                      approxPolyDP(approx_con, approx_con1, arcLength(approx_con, true)*0.005, true);
                      if ((approx_con1.size() == 4 ) && (area2 < SQmaxf)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                            {
                                //cosine = fabs(a_angle(approx[j%4], approx[j-2], approx[j-1]));
                                cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                                maxCosine = MAX(maxCosine, cosine);
                              }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                        //  printf("Q3 \n");
                        //if( maxCosine < MCosine ){
                            // 新しいベクターを作成し、approx_con1をコピー
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqaの末尾に新しい四角形を追加
                            sqa.push_back(new_square);
                          //drawContours(mask0,sqa,-1,Scalar(255),CV_FILLED);
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



//
static int findSq( const Mat& image, const Mat& imageGR, vector<vector<cv::Point> >& sq )
{
  int hight = image.rows;
  int width = image.cols;
  int SQmaxf = hight*width/6;  // 2024-1-16 変更　4--?6  メイン画像からのブロックはおおき過ぎるため
  //printf("SQmaxf=%d",SQmaxf);
    //Mat img1 = image.clone();
    //Mat img=Mat(image.size(),CV_8UC3,Scalar(0,0,0));// for New-mask
      vector<cv::Point> approx;
      vector<cv::Point> approx_con,approx_con1;
      //vector<cv::Point> approx1;
      vector<vector<cv::Point> > contours;
      vector<vector<cv::Point> > contours1;
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
      ////////////////////////////filter は検討要する
      cvtColor(image, gray1, COLOR_BGR2GRAY);
      equalizeHist(gray1,gray);
          //imshow("FindSQ eq-image",gray);
      medianBlur(gray,mt,5);// 3:追加2-20 おかしかったら削除のこと

      Canny(mt, dest, 60,180, 3);
      //imshow("FQ-1-canny",dest);//以下のsplitしなくてもほぼ同じ　以下変更２－２

///////////////2025-6-6 test////////////////
      vector<Vec4i> lines;/////////////////////////////////*********************check

      HoughLinesP( dest, lines, 1, CV_PI/180, 80, 100, 20 );// 最小の線分長さ、2点の距離 100 20 がベターかな
      /////////////////2025-6-16 setting 100,20
      //HoughLinesP( dest, lines, 1, CV_PI/180, 80, 60, 20 );// 最小の線分長さ、2点の距離
      for( size_t i = 0; i < lines.size(); i++ )
      {
          //line( image, cv::Point(lines[i][0], lines[i][1]),cv::Point(lines[i][2], lines[i][3]), Scalar(0,0,0), 2, 8 );
          line( dest, cv::Point(lines[i][0], lines[i][1]),
                  cv::Point(lines[i][2], lines[i][3]), Scalar(255,255,255), 1, 8 );//////************ check
      }
      //imshow("Line?",dest);

          //dilate(mbgr, mbgr0, Mat(), cv::Point(-1,-1));// 追加2-22 影響大きいのでやめ
          morphologyEx(dest,mbgr0,MORPH_CLOSE,element,cv::Point(-1,-1),1);
          ////Orignal RGB Canny
///imshow("FSQ-2mor-canny-mbgr0",mbgr0);
      ///////////////////////New-mask での OTSU-Canny ///////yellow-maskに変更　10-29//////
      cvtColor(imageGR,gray1, COLOR_BGR2GRAY);
      medianBlur(gray1,gray,5);// 7にしてもtest2は駄目
      equalizeHist(gray,gray1);

            ////////////////////////////
      Canny(gray1, mbgr, 60,180, 3);//
            //imshow("GR-color-canny",mbgr);//以下のsplitしなくてもほぼ同じ

        /////////////////////////////////////////////////////////////////////////////////////////
          //bitwise_or(mbgr, om, nh);// 追加 2-19 S-OTSU=Canny
              bitwise_or(mbgr, mbgr0, nh);
          //bitwise_or(mbgr0, nh, nh);
      ///////////////////////////////////DIlate or Closing & findContours/////////////////////////////////
      ///// この後　Diliteした方がよいと思われるが？不明　Closing
          //morphologyEx(nh,close_img,MORPH_CLOSE,element,cv::Point(-1,-1),1);//6-10 変更した
          dilate(nh, close_img, Mat(), cv::Point(-1,-1)); // この部分がすべて結果を左右する1-30

      findContours(close_img, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);// Orignal
      findContours(mbgr0, contours1, RETR_LIST, CHAIN_APPROX_SIMPLE);
      //// RETR_EXTERNALは個別に取れないのでやめたほうがよい2018-3-2

      int s=0;int s2=0;int s3=0;
      double cosine,maxCosine;


    //////////////////////////////////////// ADD 2018-5-30
    for( size_t k = 0; k < contours1.size(); k++ )
    {
        if (s > 19) break;
        area = contourArea(contours1[k]);

        if (area > SQmin && area < SQmaxf){// orignal
            approxPolyDP(Mat(contours1[k]), approx, arcLength(Mat(contours1[k]), true)*0.01, true);// 0.01 0.05以下で
              aps = approx.size();

            if (aps == 4 && s < 10){
                  //std::cout << approx; // 上から右周りの座標
                  //                                printf( "SQ-Area1=%f\n", area );
              // Four corners of source image
                maxCosine = 0;                   //// 角度のチェック
                for( int j = 0; j < 4; j++ )
                {
                    //cosine = fabs(a_angle(approx[j%4], approx[j-2], approx[j-1]));
                    cosine = fabs(a_angle(approx[j], approx[(j+2)%4], approx[(j+3)%4]));
                    maxCosine = MAX(maxCosine, cosine);
                  }
                int check = sqch(approx);
                if(( maxCosine < MCosine )&&(check == 0)){
                  //printf("Q11 \n");
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
                if ((aps2 == 4)&&(area2 < SQmaxf)){
                      maxCosine = 0;
                      for( int j = 0; j < 4; j++ )
                      {
                        //cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                      }
                      int check = sqch(approx_con);
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
                  if ((aps2 > 4)&&(area2 < SQmaxf)){
              //approxPolyDP(Mat(contours[k]), approx_con1, arcLength(Mat(contours[k]), true)*0.05, true);// 0.05
                      approxPolyDP(approx_con, approx_con1, arcLength(Mat(contours1[k]), true)*0.005, true);
                    //////// 0.01 で４か５角形 0.005 が一番良いか？2-20
                      if ((approx_con1.size() == 4 && s < 10)&&(area2 < SQmaxf)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                          //cosine = fabs(a_angle(approx_con1[j%4], approx_con1[j-2], approx_con1[j-1]));
                          cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                          maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqの末尾に新しい四角形を追加
                            sq.push_back(new_square);
                            // sとs3を更新
                            s = (int)sq.size();
                            s3++;
                            //polylines(image, approx_con1, true, Scalar(0, 0, 255), 2);//
                            //imshow("Sq-mbgr2", image);//waitKey(0);
                        }
                      }
                      if ((approx_con1.size() == 5 && s < 10)&&(area2 < SQmaxf)){
                        vector<cv::Point> quad;
                        Get_quad( approx_con1, quad);
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                            //cosine = fabs(a_angle(quad[j%4], quad[j-2], quad[j-1]));
                            cosine = fabs(a_angle(quad[j], quad[(j+2)%4], quad[(j+3)%4]));
                            maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(quad);
                        if(( maxCosine < MCosine )&&(check == 0)){
                        //  printf("Q14 \n");
                        //if( maxCosine < MCosine ){
                        //std::cout << quad;
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
    //////////////////////////////////////////////////////
    for( size_t k = 0; k < contours.size(); k++ )
    {
        if (s > 9) break;
        area = contourArea(contours[k]);

        if (area > SQmin && area < SQmaxf){// orignal
            approxPolyDP(Mat(contours[k]), approx, arcLength(Mat(contours[k]), true)*0.01, true);// 0.01 0.05以下で
              aps = approx.size();

            if (aps == 4 && s < 10){
                  //std::cout << approx; // 上から右周りの座標
                                                    //printf( "SQ-Area2=%f\n", area );
              // Four corners of source image
                maxCosine = 0;                   //// 角度のチェック
                for( int j = 0; j < 4; j++ )
                {
                    cosine = fabs(a_angle(approx[j], approx[(j+2)%4], approx[(j+3)%4]));
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
            /////if (aps > 4 && aps < 9 && s < 10){////＊＊＊＊＊＊＊＊
              if (aps > 4 && s < 10){
                convexHull(approx,approx_con);// 凸図形に
    //convexHull(Mat(contours[k]),approx_con);// 上と比較して全体で個数が減る？3-5
                    //// 0.1とかに大きくするとsizeが２とかになる？？？？1-31
                area2 = contourArea(approx_con);
                aps2 = approx_con.size();
                if ((aps2 == 4)&&(area2 < SQmaxf)){
                      maxCosine = 0;
                      for( int j = 0; j < 4; j++ )
                      {
                        //cosine = fabs(a_angle(approx_con[j%4], approx_con[j-2], approx_con[j-1]));
                        cosine = fabs(a_angle(approx_con[j], approx_con[(j+2)%4], approx_con[(j+3)%4]));
                        maxCosine = MAX(maxCosine, cosine);
                      }
                      int check = sqch(approx_con);
                      if(( maxCosine < MCosine )&&(check == 0)){
                      //  printf("Q8 \n");
                      //if( maxCosine < MCosine ){
                          std::vector<cv::Point> new_square = approx_con;
                          // sqの末尾に新しい四角形を追加
                          sq.push_back(new_square);
                          // sとs2を更新
                          s = (int)sq.size();
                          s2++;
                      }
                }
               /////// if ((aps2 > 4)&&(aps2 < 9)&&(area2 < SQmax)){//////＊＊＊＊＊＊＊＊
                    if ((aps2 > 4)&&(area2 < SQmaxf)){
              //approxPolyDP(Mat(contours[k]), approx_con1, arcLength(Mat(contours[k]), true)*0.05, true);// 0.05
                      approxPolyDP(approx_con, approx_con1, arcLength(Mat(contours[k]), true)*0.005, true);
                    //////// 0.01 で４か５角形 0.005 が一番良いか？2-20
                      if ((approx_con1.size() == 4 && s < 10)&&(area2 < SQmaxf)){
                        maxCosine = 0;
                        for( int j = 0; j < 4; j++ )
                        {
                          //cosine = fabs(a_angle(approx_con1[j%4], approx_con1[j-2], approx_con1[j-1]));
                          cosine = fabs(a_angle(approx_con1[j], approx_con1[(j+2)%4], approx_con1[(j+3)%4]));
                          maxCosine = MAX(maxCosine, cosine);
                        }
                        int check = sqch(approx_con1);
                        if(( maxCosine < MCosine )&&(check == 0)){
                        //  printf("Q9 \n");
                            // 新しいベクターを作成し、approx_con1の頂点をコピー
                            std::vector<cv::Point> new_square = approx_con1;
                            // sqの末尾に新しい四角形を追加
                            sq.push_back(new_square);
                            // sとs2を更新
                            s = (int)sq.size();
                            s2++;
                            //polylines(image, approx_con1, true, Scalar(0, 0, 255), 2);//
                            //imshow("Sq-2", image);//waitKey(0);
                        }
                      }
                      if ((approx_con1.size() == 5 && s < 10)&&(area2 < SQmaxf)){
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
                        //  printf("Q10 \n");
                        //if( maxCosine < MCosine ){
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
    //printf("SQs1=%d SQs2=%d SQs3=%d\n",s,s2,s3);
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
    for (int n=1;n<sqindex; n++){
        x0=0;y0=0;// これがなかったため値が全て加算されていた6-28 以下同じ
        for (int i=0; i<4; i++){
            x0+=(int)sq[n][i].x;// 次のｓｑの重心
            y0+=(int)sq[n][i].y;
        }
        x0/=4;   y0/=4;
        onaji=0;
        for (int t=0; t<s; t++)// セーブしてあるSq　ｓ個
        {
            x=0;y=0;
            for (int i=0; i<4; i++){
                x+=(int)Sq[t][i].x;// ｓｑの重心
                y+=(int)Sq[t][i].y;
            }
            x/=4;  y/=4;
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

    ///////////////////////次の４角形 adap///////
    if (sqaindex == 0) return s;

    for (int n=ss; n<sqaindex; n++){
        x0=0;y0=0;
        for (int i=0; i<4; i++){
            x0+=(int)sqa[n][i].x;// 次のｓｑの重心
            y0+=(int)sqa[n][i].y;
        }
        x0/=4;   y0/=4;
        onaji=0;
        for (int t=0; t<s; t++)// セーブしてあるSq　ｓ個
        {
            x=0;y=0;
            for (int i=0; i<4; i++){
                x+=(int)Sq[t][i].x;// ｓｑの重心
                y+=(int)Sq[t][i].y;
            }
            x/=4;  y/=4;
            //　セーブしているｓｑの重心の ある範囲以内なら　同一としてブレイク
            if ( (x0+DD > x)&&(x0 < x+DD) && (y0+DD > y)&&(y0 < y+DD) )
            { onaji=1;
                break;
            }
        }
        if (onaji==0){
            std::vector<cv::Point> new_square = sqa[n];
            Sq.push_back(new_square);
            //std::cout << sq[n];
            s = (int)Sq.size();
        }
    }

    return s;
}


/////////////////////////////////////////////////////////////////
/////////////////とれた四角形によるマスク　この中で三角形をさがす　 ////////背景黒と白の２種類をリターン
// meanの追加と　戻り画像をカラーからGrayに変更
static int Trmask(const Mat& image, vector<vector<cv::Point> >& sq, int sqindex, const Mat& trimage, const Mat& trimageW, int &maskmean)
{
  if (sqindex == 0) return -1;
  int hight = image.rows;
  int width = image.cols;
  Mat mask = Mat::zeros(hight, width, CV_8UC1);//back 黒
  //Mat mask = Mat::zeros(image.rows, image.cols, CV_8UC1);//back 黒
  Mat gray(image.size(), CV_8U);

  int a0,a1,a2,a3;
  int b0,b1,b2,b3;
  int ax[4],bx[4];
  int sx[4],sy[4];
  double A,Aa[4];
  cv::Point pt[4]; //任意の4点を配列に入れる

  for (int n=0; n < sqindex; n++){ // sqindex は　ＳＱ個数
        int er=0;
        for (int i=0; i<4; i++){
          sx[i]=(int)sq[n][i].x;// ax 右回りかどうか不明
          sy[i]=(int)sq[n][i].y;
          if ( ((width-7) < sx[i]) || (7 > sx[i]) || ((hight-7) < sy[i]) || (7 > sy[i]) )
            { er=1; break;}/////この部分2023-9-4日テスト 全体画像枠での　4角形辺　取得によるエラー対策////
        }
        if (er==1) continue;
    ////////////並べ替え　右か左か不明なので　右回りにする/////修正要する　６－１１///////////////////////////////
      A=0;//外積での＋－判断　Ａ＜０なら左回り
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
          cvtColor(image, gray, COLOR_BGR2GRAY);
    image.copyTo(trimage,mask);
    //gray.copyTo(trimage,mask);// Gray画像で返すよう変更　2023/11/19　次のfindTrで結局またGrayに変換してから使っているので
          //maskmean = mean(image, mask)[0]; // カラー画像のmeanは役に立たない
          //printf("Mask-mean0 : %d\n" ,maskmean);
          maskmean = mean(gray, mask)[0];
          //printf("gray-mean0 : %d\n" ,mean0);
        //imshow("TR-Image", trimage );// 黒背景
    image.copyTo(trimageW,mask);// 白背景
    //gray.copyTo(trimageW,mask);//
        //imshow("TR-ImageW", trimageW );
return 0;    ////////////////////////////////
}

////////////////////////////////////////////

//////////////////////////////////////////////
static int findTr( const Mat& image, const Mat& imageW, vector<vector<cv::Point> >& tr, int &t, vector<vector<cv::Point> >& trw, int &tw, int maskmean)
{   vector<vector<cv::Point> > contours;
    vector<vector<cv::Point> > contours0;
    vector<vector<cv::Point> > contours1;
    vector<vector<cv::Point> > contours2;
    vector<cv::Point> approx;
    Mat element = getStructuringElement(MORPH_RECT,cv::Size(3,3));
    double area;
    Mat mt,mta,mtb,mtw;
    //Mat mtb,mtw;
    Mat gray(image.size(), CV_8U);
    Mat gray0;
    Mat grayw(imageW.size(), CV_8U);
    Mat gray1;

    t=0;              // 三角形個数
    tw=0;

    ///////  Canny
    //               medianBlur(image,mt,5);
    medianBlur(image,mt,3);// 3の方が小さい三角もとれるのでは？　2025/06/16

    cvtColor(mt, gray, COLOR_BGR2GRAY);
    //imshow("Gray", gray);
    //Canny( gray, gray0, 60, 120,3 );
    //imshow("Normal-Canny-120",gray0);
    Canny( gray, gray0, 60, 180,3 );
    //imshow("Normal-Canny-180",gray0);
    morphologyEx(gray0,mtb,MORPH_CLOSE,element,cv::Point(-1,-1),1);// 三角頂点がつながらないケースあり必要2019-12-29
    findContours(mtb, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);//Canny
    //findContours(gray0, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);//Canny
          //imshow("TR-black-morph", mtb);
        for( size_t i = 0; i < contours.size(); i++ )     //Canny Black
        {
              if (t > 5) break;
              area = contourArea(contours[i]);
              if (area > TRmin && area < TRmax){   //画像サイズ640の時100　1000なら200
                //
                approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.05, true);//0.05
              //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
                if (approx.size() == 3 && t < 5 ){
                  //printf( "FindfTr-Area=%f\n", area );
                        int Tx = ( ((int)approx[0].x) + ((int)approx[1].x) +  ((int)approx[2].x) ) / 3;
                        int Ty = ( ((int)approx[0].y) + ((int)approx[1].y) +  ((int)approx[2].y) ) / 3;
                        int b=0;
                        int w=0;

                        for (int y=Ty-1; y<Ty+2; y++)// このエリアが黒ならＯＫ　重心のまわり９ピクセル
                              for (int x=Tx-1; x<Tx+2; x++)
                              {
                                int color0 = gray.at<unsigned char>(y,x);
                                //printf("Canny-B =%d ",color0);
                                if (color0 < CheckBW) //黒チェック  200-->100--> 150  2024-3-7
                                b++;
                                else  w++;///
                              }
                            //printf("Canny-TR BWcheck B=%d W=%d \n",b,w);

                      if (b<w) //continue;
                      {
                          std::vector<cv::Point> new_triangle = approx;
                          trw.push_back(new_triangle);
                          tw = (int)trw.size();
//                          trw[tw].push_back(cv::Point(approx[0].x, approx[0].y));
//                          trw[tw].push_back(cv::Point(approx[1].x, approx[1].y));
//                          trw[tw].push_back(cv::Point(approx[2].x, approx[2].y));
                //polylines(imageW, trw[tw], true, Scalar(0, 0, 255), 2);//赤
                          //tw++;
                      }
                      else
                      {
                          std::vector<cv::Point> new_triangle = approx;
                          tr.push_back(new_triangle);
                          t = (int)tr.size();
//                          tr[t].push_back(cv::Point(approx[0].x, approx[0].y));
//                          tr[t].push_back(cv::Point(approx[1].x, approx[1].y));
//                          tr[t].push_back(cv::Point(approx[2].x, approx[2].y));
              //  polylines(image, tr[t], true, Scalar(255, 0, 0), 2);//青
                          //t++;
                      }

                    }
              }
          }
  /////////////////////////////
  // 黒 3角　Adap
    if(maskmean > 100){
      ///////////////////////////////////////// test 2025-6-15 元に戻す
              adaptiveThreshold(gray,mta,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);
                //imshow("Black-adap-41-21", mta);
              //adaptiveThreshold(gray,mta,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,67,55);
              //imshow("Black-adap-67-55", mta);

              findContours(mta, contours1, RETR_LIST, CHAIN_APPROX_SIMPLE);
              for( size_t i = 0; i < contours1.size(); i++ )    // Adap Black 3角
              {
                if (t > 5) break;
                area = contourArea(contours1[i]);
                if (area > TRmin && area < TRmax){   //画像サイズ640の時100　1000なら200
                  approxPolyDP(Mat(contours1[i]), approx, arcLength(Mat(contours1[i]), true)*0.05, true);//0.05
                //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
                  if (approx.size() == 3 && t < 5 ){
                    //printf( "FindfTr-adp-Area=%f\n", area );
          //  polylines(image, approx, true, Scalar(0,255,0), 2);// Test表示はここ
                            //printf( "im_out TRA  %d %d  \n ", (int)approx[j].x, (int)approx[j].y  );
                            /////////////////////// この部分追加　2023-10-3
                            ////////////////////////////////////////////////
                            int Tx = ( ((int)approx[0].x) + ((int)approx[1].x) +  ((int)approx[2].x) ) / 3;
                            int Ty = ( ((int)approx[0].y) + ((int)approx[1].y) +  ((int)approx[2].y) ) / 3;
                            int b=0;
                            int w=0;

                            for (int y=Ty-1; y<Ty+2; y++)// このエリアが黒ならＯＫ　重心のまわり９ピクセル
                              for (int x=Tx-1; x<Tx+2; x++)
                              {
                                int color0 = gray.at<unsigned char>(y,x);
                                if (color0 < CheckBW) //黒チェック  200-->100
                                      b++;
                                else  w++;///
                              }
                            //printf("Adap-B BLack WHite = %d %d \n",b,w);
                          //printf( " TrBW B=%d W=%d \n", b,w);
                            if (b<w) continue;
                    // Three corners of source image is saved to tr[]
                      std::vector<cv::Point> new_triangle = approx;
                      tr.push_back(new_triangle);
                      t = (int)tr.size();
//                        tr[t].push_back(cv::Point(approx[0].x, approx[0].y));
//                        tr[t].push_back(cv::Point(approx[1].x, approx[1].y));
//                        tr[t].push_back(cv::Point(approx[2].x, approx[2].y));
                    //polylines(image, tr[t], true, Scalar(255, 0,255), 2);// pink
                        //t++;
                      }
                    }
                  }
            /////////////////////////////////////////////////////////////////////////////////////////////
            ////////////////////////////////////////////////////////////////////////////////////////////////

          adaptiveThreshold(gray,mtb,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);// 通常の黒三角はこれでOK　従来どおり
          findContours(mtb, contours0, RETR_LIST, CHAIN_APPROX_SIMPLE);//normal black
          //imshow("Black-adap-41-21", mtb);
          /////////////////////////////
            for( size_t i = 0; i < contours0.size(); i++ )    // Adap Black 3角
            {
              if (t > 5) break;
              area = contourArea(contours0[i]);
              if (area > TRmin && area < TRmax){   //画像サイズ640の時100　1000なら200
                approxPolyDP(Mat(contours0[i]), approx, arcLength(Mat(contours0[i]), true)*0.05, true);//0.05
              //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
                if (approx.size() == 3 && t < 5 ){
                  //printf( "FindfTr-adp-Area=%f\n", area );
          //polylines(image, approx, true, Scalar(0,255,0), 2);// Test表示はここ
                          //printf( "im_out TRA  %d %d  \n ", (int)approx[j].x, (int)approx[j].y  );
                          /////////////////////// この部分追加　2023-10-3
                          ////////////////////////////////////////////////
                          int Tx = ( ((int)approx[0].x) + ((int)approx[1].x) +  ((int)approx[2].x) ) / 3;
                          int Ty = ( ((int)approx[0].y) + ((int)approx[1].y) +  ((int)approx[2].y) ) / 3;
                          int b=0;
                          int w=0;

                          for (int y=Ty-1; y<Ty+2; y++)// このエリアが黒ならＯＫ　重心のまわり９ピクセル
                            for (int x=Tx-1; x<Tx+2; x++)
                            {
                              int color0 = gray.at<unsigned char>(y,x);
                              if (color0 < CheckBW) //黒チェック  200-->100
                                    b++;
                              else  w++;///
                            }
                          //printf("Adap-B BLack WHite = %d %d \n",b,w);
                        //printf( " TrBW B=%d W=%d \n", b,w);
                          if (b<w) continue;
                  // Three corners of source image is saved to tr[]
                    std::vector<cv::Point> new_triangle = approx;
                    tr.push_back(new_triangle);
                    t = (int)tr.size();
//                      tr[t].push_back(cv::Point(approx[0].x, approx[0].y));
//                      tr[t].push_back(cv::Point(approx[1].x, approx[1].y));
//                      tr[t].push_back(cv::Point(approx[2].x, approx[2].y));
                  //polylines(image, tr[t], true, Scalar(255, 0,255), 2);// pink
                      //t++;
                    }
                  }
                }

      }

// 白3角形
  if(maskmean <= 100)
      {
          //medianBlur(imageW,mt,5);
          medianBlur(imageW,mt,3);// 2025-6-16
          ///medianBlur(imageW,grayw,5);
          cvtColor(mt, gray1, COLOR_BGR2GRAY);//　白
          //imshow("image4-gray",gray1);// バック白
          bitwise_not(gray1,grayw);//inverce 白

          adaptiveThreshold(grayw,mtw,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,15);//白三角はこちらの方がよいかも？
          findContours(mtw, contours2, RETR_LIST, CHAIN_APPROX_SIMPLE);
              //imshow("White-adap-41-15", mtw);
              for( size_t i = 0; i < contours2.size(); i++ )  // Adap White 3角
              {
                if (tw > 19) break;
                area = contourArea(contours2[i]);
                if (area > TRmin && area < TRmax){   //画像サイズ640の時100　1000なら200
                  approxPolyDP(Mat(contours2[i]), approx, arcLength(Mat(contours2[i]), true)*0.05, true);//0.05
              //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.02, true);
                  if (approx.size() == 3 && tw < 20 ){
                    //printf( "FindfTr-adp-Area=%f\n", area );
                        /////////////////////// この部分追加　2023-10-3
                        int Tx = ( ((int)approx[0].x) + ((int)approx[1].x) +  ((int)approx[2].x) ) / 3;
                        int Ty = ( ((int)approx[0].y) + ((int)approx[1].y) +  ((int)approx[2].y) ) / 3;
                        int b=0;
                        int w=0;
                        for (int y=Ty-1; y<Ty+2; y++)// このエリアが黒ならＯＫ　重心のまわり９ピクセル
                          for (int x=Tx-1; x<Tx+2; x++)
                          {
                            int color0 = gray1.at<unsigned char>(y,x);
                            ///printf("Adap-W = %d ",color0);
                            if (color0 < CheckBW) //黒チェック  200-->100
                            b++;
                            else  w++;///
                          }
                          ///printf("Adap-W BLack WHite = %d %d \n",b,w);
                          //printf( " TrBW B=%d W=%d \n", b,w);
                        if (b>w) continue;
                        ////////////////////////////////////////
                        ////////////////////////////////////////
                  // Three corners of source image is saved to tr[]
                      std::vector<cv::Point> new_triangle = approx;
                      trw.push_back(new_triangle);
                      tw = (int)trw.size();
//                      trw[tw].push_back(cv::Point(approx[0].x, approx[0].y));
//                      trw[tw].push_back(cv::Point(approx[1].x, approx[1].y));
//                      trw[tw].push_back(cv::Point(approx[2].x, approx[2].y));
                  //polylines(imageW, trw[tw], true, Scalar(0, 255,255), 2);//黄色
                      //tw++;
                    }
                  }
              }
          }

  /////////////////////////////////////////////
  //imshow("Result-TR-black", image);
  //imshow("Result-TR-white", imageW);
    if ((t == 0)&&(tw == 0))  return 0;
  return 1;
}

//////////////////////////////////////////////////////////////
/////////////Trcheck ３角形のダブりチェック 6-21 修正　バグ修正　２０１９－２－２０ 　　　2025-8

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
        if (lt[jmax] > lt[jmin]*49)  continue;//長辺が短辺の7倍以上なら除外 2025-8
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
        if (onaji==0){
            std::vector<cv::Point> new_triangle = tr[n];

            // Trの末尾に新しい三角形を追加
            Tr.push_back(new_triangle);

            // Trf[s] = Trf[n]; の代わりに、安全な方法でTrfに要素を追加
            // たとえば、Trfもstd::vectorであれば
            // Trf.push_back(Trf[n]);

            // sをTrの実際のサイズに同期させる
            s = (int)Tr.size();
        }
    }
    return s;
}



////////////////////////////////////////////////////////////////////////////////
static int Angl=-1;// angl  から　Angl　へ変更　6-26
static long Code=0;
static int TRC=8;// 射影後の三角形のブレ範囲 +-5
/////// return -1  0;１個のみ取れた時　1:２個取れた時　正常はコードCode Angl を返す

static int FHomo(const Mat& image, vector<vector<cv::Point> >& sq, int sqindex, vector<vector<cv::Point> >& tr, int trindex, int TrBW)
{// TrBW 追加　3角の色で別々にFHomoを行う　2023/10/17
  if ((sqindex == 0)||(trindex == 0)) return -1;
  //printf("FHomo=SQ=%d TR=%d ",sqindex,trindex);
  /////////////////////////////test for drowing 2023-1-23 ///////////////////
        int hight = image.rows;
        int width = image.cols;
        //Mat mask = Mat::zeros(hight, width, CV_8UC1);//back 黒
  ////////////////////////////////////////////////
  Mat img = image.clone();
  Mat img0,gray,gray1;
      medianBlur(img,img0,5);/////この部分追加2023/09/06
      cvtColor(img0, gray, COLOR_BGR2GRAY);
      //imshow("image-gray", gray);
            //Mat mask = Mat::zeros(hight, width, CV_8UC1);//back 黒
            Mat mask = Mat(image.size(), CV_8UC3, Scalar(0));// 背景　黒
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
        for (int i=0; i<4; i++){  ///////////////
          sx[i]=(int)sq[n][i].x;
          sy[i]=(int)sq[n][i].y;
        }
        //    printf("            SQ-n=%d  \n",n);

    ////////////並べ替え　右か左か不明なので　右回りにする////////////////////////////////////
      A=0;//外積での＋－判断　Ａ＜０なら左回り
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
  /////////////横の辺が上部短辺の2倍以上あるときは除外　8-12 ////カメラが横向きで斜め//////////////////////////
  //printf("size-check start");
        double m1=4*((a1-a0)*(a1-a0)+(b1-b0)*(b1-b0));
        double m2=((a2-a1)*(a2-a1)+(b2-b1)*(b2-b1));
        //printf( "M1 M2=%lf %lf\n", m1,m2 );
        if (b1<=b3)
          if (m1<m2) {

              continue;
            }
        if (b1>b3)
          if (4*((a3-a0)*(a3-a0)+(b3-b0)*(b3-b0)) < ((a3-a2)*(a3-a2)+(b3-b2)*(b3-b2)))
              continue;


        polylines(mask, sq[n], true, Scalar(255), 1);// この部分後で使う　 3角が四角に接して以内かの為　重要　　　白ラインの4角形
  //////////// ここまで4角形のチェック

  //imshow("FHomo-SQ", img);
  ////// 以下エラー処理必要　０割り算
    // 以下は後で使うのです　2024－1－28
        double b_2=0,b_3=0,b_4=0,b_5=0;
        if(a0 != a1)
          b_2=(a0*b1-a1*b0)/(a0-a1);// 線分　一次方程式　y=ax+b　の　bの値
        if(a2 != a1)
          b_3=(a1*b2-a2*b1)/(a1-a2);
        if(a2 != a3)
          b_4=(a2*b3-a3*b2)/(a2-a3);
        if(a3 != a0)
          b_5=(a3*b0-a0*b3)/(a3-a0);
/////////////////////////////////////////

      int ti=0; // 2024-1-27 test

      for (m=0; m < trindex; m++){
        int idx=0;
        double S;
          //        3角形面積と4角形面積の比較　500倍は適当　実際の限度は150倍
          //        小さな3角形をキャンセルするため
                    double areaS,areaT;
                    areaS = contourArea(sq[n]);
                    areaT = contourArea(tr[m]);
                    //printf( "                     SQ%d TR%d Area= %lf %lf\n", n,m, areaS,areaT );
                    if(areaT*500 < areaS) break;

          for ( int i=0; i<3; i++)
          { // ３角形の頂点座標　３点とも４角形内にあるか?
                  tx[i]=(int)tr[m][i].x;
                  ty[i]=(int)tr[m][i].y;
            // if ( a1>=tx[i] || a3<=tx[i] || ty[i]<=b0 || ty[i]>=b2)
                if ( minx>=tx[i] || maxx<=tx[i] || ty[i]<=miny || ty[i]>=maxy)
                  { //printf("break Tr-No.=%d \n",m);
                    break;}
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
                //////////////追加チェック　2024-1-23/////////3角の頂点が4角形の辺と重なっているエラー対策
                //////////////3角頂点の近傍枠　10✕10の線上に4角形辺が交差してるかどうか 交差してなければ　2カ所のみ
                ///////////////////// この10✕10がOKかは要確認
                  int y=ty[i];
                  int x=tx[i];
                  int w=0;
                  for (int j=0; j<10; j++)
                  {
                    int colory = mask.at<unsigned char>(y-5, x-5+j);
                          if (colory > 200) w++;//白チェック
                        colory = mask.at<unsigned char>(y+5, x-5+j);
                          if (colory > 200) w++;//白チェック
                    int colorx = mask.at<unsigned char>(y-5+j, x-5);
                          if (colorx > 200) w++;//白チェック
                        colorx = mask.at<unsigned char>(y-5+j, x-5);
                          if (colorx > 200) w++;//白チェック
                  }
                        //  printf("                        W-Closs %d = %d\n ", i,w);
                  if (w>0) break;
                ////////////////////////////////////////////////////
                //////////////// ここまでは4角に3角が含まれることのチェック
            idx++;
          }
        ////////////////////////////ここまでＯＫ
        ////
        //if (idx==3)  ti++;
        //if (ti>1) break;   ///  test 2024-1-27  to Next SQ  4角形内に複数の3角形があるときはその4角はキャンセル
            //////////////////////
      ///////////////////////////////////////////////////////////////////////////////////////////////
        if (idx==3){
          //３角形がこの４角形にふくまれる SQ[n] TR[m]
                        //printf("    OK SQ-n=%d TR-m=%d TrBW=%d  \n",n,m,TrBW);
           /////////////////////////////////////
                        /*double area3 = heron3( tx,  ty);// 3角形の頂点座標を渡す x[3],y[3]
                        printf("                               area3  is %f \n", area3);
                        */
            /////////////////////////////////////////////
                        double areaS,areaT;//TEST
                        areaS = contourArea(sq[n]);//TEST
                        areaT = contourArea(tr[m]);//TEST
                        //printf( "                            SQ TR Area= %lf %lf\n", areaS,areaT );//TEST

      ///////// 以降　1-15 追加 三角が四角のどの角に近いか判定して射影する必要あり 1-15
                long ll[4];// ４角形の頂点と３角形の１点との距離（２乗)
                int ii;
                for(ii=0;ii<4;ii++)
                  ll[ii] =  (ax[ii]-tx[0])*(ax[ii]-tx[0]) + (bx[ii]-ty[0])*(bx[ii]-ty[0]);
                  ii=minl_return(ll);
          /////////////      ax[ii]が射影後　４角形の左上の頂点になる
          //printf("  AX BX = %d %d ",ax[ii],bx[ii]);
          //////////////４角形 左上の頂点に最も近い三角形の頂点を探す　ij
                  int ij;
                  int ttx[3],tty[3];

                  for(int ij=0;ij<3;ij++)
                    ll[ij] =(ax[ii]-tx[ij])*(ax[ii]-tx[ij]) + (bx[ii]-ty[ij])*(bx[ii]-ty[ij]);
                    ij = minl_return3(ll);

                    if (ll[ij]  < TRmin*0.5)
                              continue;
          //四角点と三角直角点が近すぎる時エラー
          // *0.5 は意味不明？
          ////////////////////////////////
          //////////三角座標　並べ替え　右か左か不明なので　右回りにする////////////////////////////////////
          //printf("\ntx0 ty0 =%d %d  tx1 ty1= %d %d tx2 ty2= %d %d \n",tx[0],ty[0],tx[1],ty[1],tx[2],ty[2]);
                    B=0;//外積での＋－判断　Ａ＜０なら左回り
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
          ///////////////////////////////////////////////////////////////////////////////
          ///// 以下　アングルの新しいルーチン　２０１９－２－２５
          //// ax[ii],bx[ii] のそばに三角が存在する
          angl=-1;// 判断できない時追加　境界の時　幅を持たせる必要あり
              int p = ii;  // 以下のアングルはAndroidでは画像が横向きのためずれるので修正必要
/*              if (ax[0] < ax[2]){
//                    if (p==0) angl=0;// アンドロイド端末スマホ用
//                    if (p==1) angl=3;
//                    if (p==2) angl=2;
//                    if (p==3) angl=1;
    if (p==0) angl=3;
    if (p==1) angl=2;
    if (p==2) angl=1;
    if (p==3) angl=0;
}
else if (ax[0] > ax[2]){
//                    if (p==0) angl=3;
//                    if (p==1) angl=2;
//                    if (p==2) angl=1;
//                    if (p==3) angl=0;
    if (p==0) angl=2;
    if (p==1) angl=1;
    if (p==2) angl=0;
    if (p==3) angl=3;
}
*/
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
          if (angl < 0) continue;//break??
          //printf("1: Angle = %d \n", angl);
      ///////////////////////////////////////////////////////////////////////////////////
      /////////////////////////// 射影部分　ｈは変換行列
          vector<Point2f> pts_src;
          vector<Point2f> pts_dst;
    // Four corners of source image
          pts_src.push_back(Point2f(ax[ii], bx[ii]));// 上から右周りの座標
          pts_src.push_back(Point2f(ax[(ii+1)%4], bx[(ii+1)%4]));
          pts_src.push_back(Point2f(ax[(ii+2)%4], bx[(ii+2)%4]));
          pts_src.push_back(Point2f(ax[(ii+3)%4], bx[(ii+3)%4]));

          pts_dst.push_back(Point2f(0, 0));// 250---->300 へ変更2022-2-20-----
          pts_dst.push_back(Point2f(300, 0));
          pts_dst.push_back(Point2f(300, 300));
          pts_dst.push_back(Point2f(0, 300));

          Mat h = findHomography(pts_src, pts_dst);
          Mat im_out;

          warpPerspective(image, im_out, h, cv::Size(300, 300));   // GRAY画像でもいいのでは？？？
          //warpPerspective(mask, im_out2, h, Size(300, 300));
      //imshow("FHomo-sq", im_out);
          // 4角形の射影完了
          //////////////////////////////////////////////////////////////////////////////////////////
          ///////////////////
          int TX[3],TY[3];
          int RDLU=-1;// 三角の方向　0：右　1：下　2：左　3：上
          //printf( "          ***************** Start-sfindTr TrBW=%d \n",TrBW);
          int ret = sfindTr(im_out,TrBW,TX,TY,RDLU);// TX0 TY0 は四角頂点に最も近い3角頂点で以下、右回り
                                                  // Rect rect(10,10,100,100); での三角形の場所なので10ずつずれる

        if(ret != 1) continue;
//////////////////////////////////////////////////////////////////
        if (RDLU == 1) {  // Down check needed
            // if ((TX[1]<45)||(TX[1]>70)||(TY[1]<15)||(TY[1]>25)){  // (x0,y0)=(60,,20)
            if ((TX[1]<40)||(TX[1]>70)||(TY[1]<15)||(TY[1]>30)){  // (x0,y0)=(60,,20) 2025-7-7
                //printf("homo TR-ERR gx0 gx1 gy =%d %d %d \n",TX[0],TX[1],TY[1]);//waitKey(0);
                continue;//射影点が範囲内にない時
              }
            if( ( (TX[1]-TX[0]) < 12 ) || ( (TX[1]-TX[0]) > 25 ) ) {
                  //printf("homo TR-ERR X-length x1-x0 =%d  \n",TX[1]-TX[0]);
                  continue;// X方向　60
                }
            if( ( (TY[2]-TY[1]) > 65 ) || ( (TY[2]-TY[1]) < 30) ) {
                  //printf("homo TR-ERR Y-length y2-y1 =%d \n",TY[2]-TY[1]);
                  continue;// Y方向　20
                }

            if(TX[1]<TX[2]){
                if( (TX[2]-TX[1]) > TRC ) {
                    //printf("homo TR-ERR TRC x2 x1 =%d %d \n",TX[2],TX[1]);
                    continue;// gy[0]+-5 以内にgy[1]がない場合エラー
                  }
            }
            else if( (TX[2]-TX[1]) > TRC ) {
                    //printf("homo TR-ERR TRC x2 x1 =%d %d \n",TX[2],TX[1]);
                    continue;
            }

            if(TY[0]<TY[1]){
                if( (TY[1]-TY[0]) > TRC ) {
                    //printf("homo TR-ERR TRC y1 y0 =%d %d \n",TY[1],TY[0]);
                    continue;
                  }// gx[0]+-5 以内にgx[2]がない場合エラー
                }
                else if( (TY[0]-TX[1]) > TRC ) {
                  //printf("homo TR-ERR TRC y1 y0 =%d %d \n",TY[1],TY[0]);
                  continue;
                }
            }


        if (RDLU == 3) { // UP check needed
          if ((TX[2]<25)||(TX[2]>50)||(TY[2]<60)||(TY[2]>90)){  // (x0,y0)=(40,80)
              //printf("homo TR-ERR gx gy =%d %d \n",TX[0],TY[0]);//waitKey(0);
              continue;//射影点が範囲内にない時
            }
          if( ( (TX[1]-TX[2]) < 12 ) || ( (TX[1]-TX[2]) > 25 ) ) {
                //printf("homo TR-ERR X-length x1-x0 =%d  \n",TX[1]-TX[2]);
                continue;// X方向　60
              }
          if( ( (TY[2]-TY[0]) > 65 ) || ( (TY[2]-TY[0]) < 30) ) {
                //printf("homo TR-ERR Y-length y2-y1 =%d \n",TY[2]-TY[0]);
                continue;// Y方向　20
              }

          if(TX[0]<TX[2]){
              if( (TX[2]-TX[0]) > TRC ) {
                  //printf("homo TR-ERR TRC x2 x0 =%d %d \n",TX[2],TX[0]);
                  continue;// gy[0]+-5 以内にgy[1]がない場合エラー
                }
          }
          else if( (TX[0]-TX[2]) > TRC ) {
                  //printf("homo TR-ERR TRC x2 x0 =%d %d \n",TX[2],TX[0]);
                  continue;
          }

          if(TY[2]<TY[1]){
              if( (TY[1]-TY[2]) > TRC ) {
                  //printf("homo TR-ERR TRC y2 y1 =%d %d \n",TY[2],TY[1]);
                  continue;
                }// gx[0]+-5 以内にgx[2]がない場合エラー
              }
              else if( (TY[2]-TX[1]) > TRC ) {
                //printf("homo TR-ERR TRC y1 y2 =%d %d \n",TY[1],TY[2]);
                continue;
              }
            }     //continue;

        ////////////////////////////////////////
        if (RDLU == 0){
                  //if ((TX[0]<16)||(TX[0]>42)||(TY[0]<35)||(TY[0]>65)){       // 2023-11-19 再変更してみた TX-->18--->16
                  if ((TX[0]<12)||(TX[0]>42)||(TY[0]<30)||(TY[0]>65)){  // 2024-9-30 imgubへの変更による　再設定(x0,y0)=(20,40)
                    //printf("homo TR-ERR gx gy =%d %d \n",TX[0],TY[0]);//waitKey(0);
                  continue;//射影点が範囲内にない時
                  }
              //if( ( (gx[1]-gx[0]) > 65 ) || ( (gx[1]-gx[0]) < 40) ) {// 40ではエラー多い 2023-6-18
              // この部分一つ読みでは重要＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊
              if( ( (TX[1]-TX[0]) > 65 ) || ( (TX[1]-TX[0]) < 30) ) {
                //printf("homo TR-ERR X-length x1-x0 =%d  \n",TX[1]-TX[0]);
                continue;// X方向　60
              }
              if( ( (TY[2]-TY[0]) > 25 ) || ( (TY[2]-TY[0]) < 12) ) {
                //printf("homo TR-ERR Y-length y2-y0 =%d \n",TY[2]-TY[0]);
                continue;// Y方向　20
              }
              //if( ( (gx[1]-gx[0]) > 55 ) || ( (gx[1]-gx[0]) < 30) ) continue;// X方向　５０まで
              //if( ( (gy[2]-gy[0]) > 20 ) || ( (gy[2]-gy[0]) < 10) ) continue;// Y方向　１７まで

              if(TY[0]<TY[1]){
                if( (TY[1]-TY[0]) > TRC ) {
                  //printf("homo TR-ERR TRC y1 y0 =%d %d \n",TY[1],TY[0]);
                  continue;// gy[0]+-5 以内にgy[1]がない場合エラー
                }
              }
              else if( (TY[0]-TY[1]) > TRC ) {
                  //printf("homo TR-ERR TRC-2y gx gy =%d %d \n",TY[0],TY[1]);
                  continue;
              }

              if(TX[0]<TX[2]){
                if( (TX[2]-TX[0]) > TRC ) {
                  //printf("homo TR-ERR TRC-1x x2 x0 =%d %d \n",TX[2],TX[0]);
                  continue;
                }// gx[0]+-5 以内にgx[2]がない場合エラー
              }
              else if( (TX[0]-TX[2]) > TRC ) {
                //printf("homo TR-ERR TRC-2x x0 x2 =%d %d \n",TX[0],TX[2]);
                continue;
              }
        }

        if (RDLU == 2){// 6X6 三角マーク変更　2025/04/03
                //if((TX[2]<65)||(TX[2]>90)||(TY[2]<35)||(TY[2]>70)){// 逆三角の直角点　座標 6✕6　三角20✕6 (80,50)?? 2025-4-3 変更
                if((TX[2]<45)||(TX[2]>90)||(TY[2]<35)||(TY[2]>70)){// 三角の直角点　座標 6✕6　三角20✕60 (80,50)?? 2025-6-23 変更
                //printf("homo TR1-ERR x1 y1 =%d %d \n",TX[1],TY[1]);// 小さい3角も許容　黄色に黒三角
                continue;
              }
              //if( ( (gx[1]-gx[0]) > 42 ) || ( (gx[1]-gx[0]) < 20) ) {// length 33.3(40mm✕5%6)  X方向　33まで    42---->39
              if( ( (TX[2]-TX[0]) > 65 ) || ( (TX[2]-TX[0]) < 30) ) {// old \\\\length 40mm  X方向　30だとちいさいか？
                //printf("homo TR1-ERR2 x0 x1 =%d %d \n",TX[0],TX[1]);
                continue;// X方向　6✕6
              }
              //if( ( (gy[2]-gy[1]) > 20 ) || ( (gy[2]-gy[1]) < 10) ) {//Y方向　16.7
              if( ( (TY[2]-TY[1]) > 25 ) || ( (TY[2]-TY[1]) < 10) ) {//Y方向　20
                //printf("homo TR1-ERR3 y1 y2 =%d %d \n",TY[1],TY[2]);
                continue;//
             }
              if(TY[0]<TY[2]){
                if( (TY[2]-TY[0]) > TRC ) continue;// gy[1]+-5 以内にgy[0]がない場合エラー
              }
              else if( (TY[0]-TY[2]) > TRC ) continue;

              if(TX[1]<TX[2]){
                if( (TX[2]-TX[1]) > TRC ) continue;// gx[1]+-5 以内にgx[2]がない場合エラー
              }
              else if( (TX[1]-TX[2]) > TRC ) continue;

              angl=(angl+2)%4; // 6*6 特別のアングル　2025/04/15

              //printf("RDLU=2  Angle = %d \n", angl);
          }

          //////////////////////////////////////////////////////////////////////////
          polylines(img, sq[n], true, Scalar(255, 0, 0), 2);
          polylines(img, tr[m], true, Scalar(255, 0,0), 2);// 三角形をはっきりさせるため　2019-9-20

                  //fillConvexPoly(image,tr[m],Scalar(0,0,0));
                  //fillConvexPoly(image,tr[m],Scalar(255,255,255));//White
          //printf("3: SQ-TR OK \n", angl);
          //double areaT = contourArea(tr[m]);
          //      printf( "TR Area=%lf", areaT );
          //      areaT = contourArea(sq[n]);
          //      printf( "SQ Area=%lf", areaT );


          //warpPerspective(image, im_out, h, Size(300, 300));

          code[cindex] = Getcode0(im_out,TX,TY,RDLU,TrBW);//三角点すべて渡す
          //printf("    CODE=%ld ANGLE=%d \n",code[cindex], angl);
          if (code[cindex] > 0){

              tmx[cindex] = m;// m番目の３角形を記録
              Angle[cindex] = angl;
              cindex++;
                  flag=1;// 2019-6-24 追加　同じ４角形で次の三角形の処理をやめる
                  /////////////////// どこかで、使った三角を消しておく処理が必要？？？　同じ三角を何回もチェックしないように　2023-6-22
              //break;// 次の４角形
            }
  ////////////////////////////////// 射影ＯＫ
        }// if index==3.........
        if (flag == 1) { flag=0;
                          //printf("     TR-n=%d  \n",n);
                        break; }// 追加　2019-6-24 次の四角形へ
      }// Tr for文　３角形包含チェック

}// SQ for文
///////////////////////////////////////////////////////
//////////// コードの重複チェック　　バグあるかも　3-18
///// コードが２種類以上で重複があった場合はどうするか　追加チェック必要　4-2
        //printf( "           CINDEX = %d \n", cindex );
int cnt=0;
Code=0;
if (cindex==0) return -1;
///////////////
//////////////////////////////////////////////////////////////////////////////////////
      if (cindex==1) {
                //printf("      Single1-code=%ld Angle=%d \n",code[0],Angle[0]);//test
                //PlaySound("trurun.wav",NULL,SND_FILENAME | SND_SYNC);
                Code=code[0];
                Angl=Angle[0];
                return 0;
              }
///////// この部分で一個読みコードの判別を行うべき
////////// cindex が１の時は少ない　同じコードがいくつもあるので

if ((cindex > 1)&&(cindex < 7)){  //////////////////////////same code check <20 訂正　２０１９－３－１２
  //printf("cindex=%d code1=%ld tmx1=%d code2=%ld tmx2=%d \n",cindex,code[0],tmx[0],code[1],tmx[1]);
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

  /*  Code=code[0];  // この部分 2個とれて別々のコード
    Angl=Angle[0];
    printf("          Single2-code=%ld Angle=%d \n",code[0],Angle[0]);
    return 0;
    */
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
    ////////////追加2024-1-21 //////////この部分画像方向ではエラー多いので　やめる特にアンドロイド端末　2024-7-17//////////////////
    /*double uplen,downlen; // uplen が downlenn より大きいのはエラー
    idx=min_return(y);//y[idx],x[idx]が一番上の点
    if( y[(idx+1)%4] < y[(idx+3)%4] )
      { uplen = fabs( (x[idx]-x[(idx+1)%4])*(x[idx]-x[(idx+1)%4]) + (y[idx]-y[(idx+1)%4])*(y[idx]-y[(idx+1)%4]) );
        downlen = fabs( (x[(idx+2)%4]-x[(idx+3)%4])*(x[(idx+2)%4]-x[(idx+3)%4]) + (y[(idx+2)%4]-y[(idx+3)%4])*(y[(idx+2)%4]-y[(idx+3)%4]) );
      }
    else
      {
        uplen = fabs( (x[idx]-x[(idx+3)%4])*(x[idx]-x[(idx+3)%4]) + (y[idx]-y[(idx+3)%4])*(y[idx]-y[(idx+3)%4]) );
        downlen = fabs( (x[(idx+2)%4]-x[(idx+1)%4])*(x[(idx+2)%4]-x[(idx+1)%4]) + (y[(idx+2)%4]-y[(idx+1)%4])*(y[(idx+2)%4]-y[(idx+1)%4]) );
      }
    if(2*uplen > 3*downlen) { //printf("Uplen %f Downlen %f\n", uplen,downlen);
                          return -1; }
    //////////////////////////////////////////////////////////////////////////
    */

    m[0]=(x[0]-x[1])*(x[0]-x[1]) + (y[0]-y[1])* (y[0]-y[1]);
    m[1]=(x[1]-x[2])*(x[1]-x[2]) + (y[1]-y[2])* (y[1]-y[2]);
    m[2]=(x[2]-x[3])*(x[2]-x[3]) + (y[2]-y[3])* (y[2]-y[3]);
    m[3]=(x[3]-x[1])*(x[3]-x[1]) + (y[3]-y[1])* (y[3]-y[1]);
    idx = mind_return(m);
    min = m[idx]; //printf("Min=%lf",min);
    idx = maxd_return(m);
    max = m[idx]; //printf("Max=%lf",max);

    if (max < min*4) return 0;//                      この＊4も検討必要　2024-1-23
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

////////////////////////
//////////////////////////
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

static int minl_return3(long *a)
{ long min;
    int idx;
    min = a[0]; idx = 0;
    for (int j=0; j<3; j++){ if(a[j] < min){  min = a[j]; idx = j;}}
    return idx;
}

////////////////////
static int mindou_r(double *a, int n)
{ double min=999999;//a[0];// min がマイナスの時におかしくなるため変更　単位メートル 2019-4-2
  int idx=0;
  for (int j=0; j<n; j++){ if( (a[j] > 0) && (a[j] < min) ){  min = a[j]; idx = j;}}
  return idx;
}
///////////
///////////////////////////////////////////////////////////////////
// MARK: -- ３角形の直角頂点を使ったコード取得  ３角形の白黒判定
static long Getcode0( const Mat& image, int X[3], int Y[3], int RDLU, int TrBW)
{

  int black[5][5];

  unsigned char B[25];// 25ビットコード
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
/////////////////look-up-table for android
//  double gamma = 1.8;                                    // ガンマ値 1.2---->1.8
//  Mat lookUp(1,256,CV_8U);
//    uchar*  lut = lookUp.data;                                    // ルックアップテーブル用配列
//    for (int i = 0; i < 256; i++) {
//        lut[i] = pow(i / 255.0, 1 / gamma) * 255.0;        // ガンマ補正式
//    }
//////////////////////////////////

  medianBlur(img,img1,5);
  cvtColor(img1, gray1, COLOR_BGR2GRAY);
  ////////////////////////////////////
    split(img, plane);
      pl0.push_back(mask);//黒
      pl0.push_back(plane[1]);//G
      pl0.push_back(plane[2]);//R
      merge(pl0,yellow);
      cvtColor(yellow,gray, COLOR_BGR2GRAY);
      //imshow("GR-Gray",gray);
            ////////////////////////////////
    if (TrBW==1){ // White TR
      bitwise_not(gray,gray);//GR-gray-inv
    }
       //printf("\n  Get_code0 start \n" );
  //////////////////////////////////////////////////////////////////////////////
      pyrDown(gray, pyr, cv::Size(image.cols/2, image.rows/2));
      pyrUp(pyr, ygray, image.size());//ある程度影がなくなる　　ぼやけるが
      medianBlur(ygray,ygray0,7);
      if(TrBW==0){
          adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,37);// Black 41,37
          //imshow("Black-code-data41-37",mt);
        }
      else{
              adaptiveThreshold(ygray0,mt,255,ADAPTIVE_THRESH_MEAN_C,THRESH_BINARY_INV,41,21);//for White TR 41,21
              //imshow("White-41-21",mt);
        }

      //imshow("Befor Black-code",mt);
      if((RDLU==0)||(RDLU==1)||(RDLU==3)){ // 2025-2-17
          Black_point0(mt,black);
          //printf("\n 7: Black-point055");
      }
      if(RDLU==2){
          //printf("\n 7: Black-point066\n");
          Black_point(mt,black);// ここで6✕6ブロックに対応
          }
//////////////////////////////////////// ここまでは通常　////////////
  //printf("\n orignal-data B(0)W(1)=%d\n",bw);
  //////////////////////////////////////////////////////////////////////////////////////////////////
      max = 0;
      /*black[0][0]=0;
      black[0][1]=0;
      black[1][0]=0;
      black[1][1]=0;
      */
 ///// 上記　0　にしているので　RDLU周辺以外が全部 0だと以下の部分で　エラーリターンする　2025/06/23
          for (int j=0; j<5; j++)
            for(int i=0; i<5; i++)
              if (black[j][i] > max)  max = black[j][i];
          //printf("       Max point0=%d ",max);
  //  if ((max < 120) || (max > 450)) return -1;/// min 150 はちいさい　350から450へ変更　2019-11-4
  if ((max < MinblackPoint) || (max > MaxblackPoint)) return -1;// 120は大きくする必要あり？　250－－300への変更による
//////////////////////////////////以下　黒点数により　０か１に変換/////////////////////
  for ( int j=0; j<5; j++)
      for (int k=0; k<5; k++)
        //if ( (black[j][k] > ( max - 250)) && (black[j][k] > 120) ) B[5*j+k]=0x31;//変更2021-9-22
        if ( (black[j][k] < MaxblackPoint) && (black[j][k] > MinblackPoint) ) B[5*j+k]=0x31;//変更  2021-9-22 for ring type
        else B[5*j+k]=0x30;

    B[0]=0x30;//一番左上は使わない　取りあえず　　三角マーカーの黒を拾うため

    B[1]=0x30; if(RDLU==1) B[1]=0x31;//2025-2-17  仮想マークをON
    B[5]=0x30; if(RDLU==3) B[5]=0x31;//2025-2-17
    B[6]=0x30;// ２列目左2も使わない　2023-12-7
  //}
      ///////////////////////////////////////////////////////////
    long val=0;
    for ( int j=0; j<25; j++){
      //printf("B[%d]=%2x ",j,B[j]);
        switch (B[j]){
          case '0':
            val *= 2;
            break;
          case '1':
            val = val * 2 + 1;
            break;
          }
        }
    if (val==0) return -1;
    //printf("    GETCODE0=%ld  \n",val);
return val;
}
////////////////////////////////////////////
// im_out 画像内での三角形取得と RDLUチェック
static int sfindTr( const Mat& img , int TrBW, int TX[3] , int TY[3], int &RDLU)
//Canny　2024-3-31
{  vector<vector<cv::Point> > contours;   // TrBW は3角形が白か（＝1）黒（＝0）
   vector<vector<cv::Point> > contours1;

    vector<cv::Point> approx;
    Mat element = getStructuringElement(MORPH_RECT,cv::Size(3,3));
    cv::Point pt[3];

    double area;
    Mat mt,mtc,mt0,mt1;
    Mat gray,gray0,grayw;
    //Mat grayw(image.size(), CV_8U);
    //long ll[3];
    std::vector<long> ll(3);
    int ij;
    int tx[3],ty[3];
    int ttx[3],tty[3];
    double B,Ba[3];//外積TR
    ////////////////////////////////////////////////
    int X,Y;
    //////////////////////////////////
                              int can_adp = 0; // Cannyを使う:0
    int t=0;

      medianBlur(img,mt,3);//重要　2025-7-16
      //medianBlur(img,mt,5); 5 では全然駄目
      cvtColor(mt, gray, COLOR_BGR2GRAY);

      cv::Rect rect(10,10,100,100);//三角形の場所 X,Yは直角点
      Mat imgSub(gray, rect);
      //imshow("imgsub",imgSub);

      ////////////////以下　cannyのパラ変更　180-->120 2025-2-11 結果チェック要す　 OR をとってもいいかも　////////////////////
          //Canny( imgSub, gray0, 40, 180,3 );//Canny( imgSub, gray0, 60, 180,3 );
          //imshow("40-180 ",gray0);
          Canny( imgSub, gray0, 60, 120,3 );//Canny( imgSub, gray0, 60, 180,3 );
            //imshow("60-120 ",gray0);
          //printf( "    sfind 1 \n");

          morphologyEx(gray0,mtc,MORPH_CLOSE,element,cv::Point(-1,-1),1);// 三角頂点がつながらないケースあり必要2019-12-29
          findContours(mtc, contours, RETR_LIST, CHAIN_APPROX_SIMPLE); //Canny

    /////////////////////////////////////////////////
    RDLU=-1;
                                          //imshow("Gfind-TR0", gray0);
    //if(TrBW==0) // Black TR
    if(can_adp==0)// Canny
      for( size_t i = 0; i < contours.size(); i++ )
      {
          if (t > 3) break;
          area = contourArea(contours[i]);
          //printf( "  ******   sfind TR-Area=%f\n", area );
          //if (area > 200 && area < 600){   //三角画像サイズ変更　6✕6の三角は小さい為(250*250)
          if ((area > 400) && (area < TRmax)){   //三角画像サイズ変更　(300*300)2022-5-17 　450 から 350 変更2023-11-21
            //printf( "                                TR-Area-1=%f\n", area );
            // 直線近似
            approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.05, true);// 0,05 値検討必要　2023/08/12
            //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.1, true);// どちらがよいか？？？2023-12-10
            //approxPolyDP(Mat(contours[i]), approx, arcLength(Mat(contours[i]), true)*0.15, true);//全然だめ
                //printf( " ******  TRC-Area=%f approx-size=%d\n", area, approx.size());
            if (approx.size() == 3){  // && (t < 3 )){
              ////////////// 左上の頂点に最も近い三角形の頂点を探す　直角点ではない　ij
                  int tt=0;
                  for(int j=0;j<3;j++){
                  //  printf( "  Canny-Area=%f    im_out TR  %d %d   \n", area, (int)approx[j].x, (int)approx[j].y  );

                      //if( (((int)approx[j].x) > 15 )&&( ((int)approx[j].x) < 94) && (((int)approx[j].y) > 15 )&&( ((int)approx[j].y) < 94) )
                      // 　2025-2-12 RDLU の三角形範囲　RECT内　理論値正確には 20-80
                      if( (((int)approx[j].x) > 10 )&&( ((int)approx[j].x) < 94) && (((int)approx[j].y) > 10 )&&( ((int)approx[j].y) < 94) )
                      {   ll[j] = (int)approx[j].x * (int)approx[j].x + (int)approx[j].y * (int)approx[j].y;
                          tt++;
                          //printf( "                              tt=%d\n", tt );
                      }// 3角がエリア内にあるかどうかチェック2023－8－8    X>24,X＜96　は検討必要　実際は30，90 X-->16--->15 2023-12-11
                  }

                  if (tt<3) continue;//次の三角へ
                  t++;// これは？？？？？不要？  2025－6－23再導入

                  ij = minl_return3(ll.data());
                    // printf( "ij=%d\n", ij );
/////////////////////////////////////////////////追加2023－8－8//////////
                    if (ij >= 0 && ij < approx.size()) {
                    for ( int i=0; i<3; i++){ // ３角形の頂点座標
                        tx[i]=(int)approx[i].x;
                        ty[i]=(int)approx[i].y;
                    }
                    
                        //////////三角座標　並べ替え　右か左か不明なので　右回りにする 4角形の頂点に最も近い三角点　pt[0].x pt[0].y ttx[0],tty[0]を基準にして右周り///////
                        B=0;//外積での＋－判断　B＜０なら左回り
                        for (int i=0;i<3;i++)
                        { Ba[i]=tx[i]*ty[(i+1)%3] - tx[(i+1)%3]*ty[i];
                            B = B+Ba[i];
                        }
                        //printf("B=%f",B);
                        if (B<0)
                        {
                            pt[0].x=tx[ij];
                            pt[0].y=ty[ij];
                            pt[1].x=tx[(ij+2)%3];
                            pt[1].y=ty[(ij+2)%3];
                            pt[2].x=tx[(ij+1)%3];
                            pt[2].y=ty[(ij+1)%3];
                            TX[0]=tx[ij];
                            TY[0]=ty[ij];
                            TX[1]=tx[(ij+2)%3];
                            TY[1]=ty[(ij+2)%3];
                            TX[2]=tx[(ij+1)%3];
                            TY[2]=ty[(ij+1)%3];
                            
                        }
                        else{
                            pt[0].x=tx[ij];
                            pt[0].y=ty[ij];
                            pt[1].x=tx[(ij+1)%3];
                            pt[1].y=ty[(ij+1)%3];
                            pt[2].x=tx[(ij+2)%3];
                            pt[2].y=ty[(ij+2)%3];
                            TX[0]=tx[ij];
                            TY[0]=ty[ij];
                            TX[1]=tx[(ij+1)%3];
                            TY[1]=ty[(ij+1)%3];
                            TX[2]=tx[(ij+2)%3];
                            TY[2]=ty[(ij+2)%3];
                        }
                        //printf(" Canny-TR TX0 TY0 =%d %d  TX1 TY1= %d %d TX2 TY2= %d %d\n",TX[0],TY[0],TX[1],TY[1],TX[2],TY[2]);
                        //////
                        /////////////////////////////上記　三角の最も大きい角度の点を探す　これが直角点
                        double cosine[3];
                        double cosine0[3];
                        for( int j = 0; j < 3; j++ ){
                            //cosine[j] = fabs(a_angle( approx0[(j+1)%3], approx0[(j+2)%3],approx[j] ));
                            //cosine0[j] = a_angle( pt[(j+1)%3], pt[(j+2)%3],pt[j] );
                            cosine[j] = fabs(a_angle( pt[(j+1)%3], pt[(j+2)%3],pt[j] ));
                            //printf("cos=%lf \n",cosine[j]);
                        }
                        int tmin=mintd_return(cosine);//最も大きい角度の点　これだけでは判断出来ない
                        int tmax=maxtd_return(cosine);// 最も小さい角度の点
                        //printf( " tmin=%d tmax=%d \n", tmin,tmax );
                        
                        //この部分以下修正必要　　RDLU の判断　2025/06/23以降検討　新しい三角LEFT
                        if(tmin==0) RDLU=0;//3角形向き　Right
                        if(tmax==2) RDLU=1;//Down
                        
                        if((tmax==0)&&(tmin==2)){
                            if ((TY[0] < TY[1]) && (TY[0] < TY[2])) RDLU=3;//UP
                            else RDLU=2;//Left
                        }
                        ////////  if((tmax==0)&&(tmin==2)) RDLU=2;//Left UP  これでは同じなので
                        /////////////////////////////////////////////////////////////////////
                        //printf( " Ca-RDLU=%d  \n", RDLU );
                        if ((RDLU >= 0)&&(RDLU <= 3)) return 1;
                        if(RDLU<0) continue;
                        /////////////////////////////////////////////////////////////////////////////////
                }
                }
          }
      }//Canny

  //////////////////////////////////////////
    if (t == 0)  return -2;
  return 0;
}

////////////////////////////////////////


///////////////////////////////　6✕6ブロック　２５個の突起の黒点数算出/////Get_codeよりcall
static void Black_point(const Mat& mt, int black[5][5])
{
    int x,y,x0,y0;
    //////////////////// 周囲の枠を塗りつぶし/////// これは効果的　////////////////////
    // Red，太さ3，4近傍連結
    //rectangle(mt, cv::Point(0,0), cv::Point(250, 250), Scalar(0,0,0), 5, 4);
    rectangle(mt, cv::Point(0,0), cv::Point(300, 300), Scalar(0,0,0), 5, 4);
      //imshow("Rectangle-RRR",mt);
    for(  int j = 0; j < 5; j++ )
        for( int k = 0; k < 5; k++)
          {
            //x0 = 42*k + 42;// 50*5%6 300--->250の為　41.6
            //y0 = 42*j + 42;
            x0 = 50*k + 50;// 300--->　50
            y0 = 50*j + 50;
            ///////////////////////
            //int XL=15,XR=15,YU=15,YD=15;// 30✕30の範囲でカウント
            int XL=20,XR=20,YU=20,YD=20;// 40✕40の範囲でカウント
            // エリア外参照チェックは省く
            ////////////////////////
            black[j][k]=0;
          /////////////////////////////////////////////////////////////////
            for (y=y0-YU; y<y0+YD; y++)
              for (x=x0-XL; x<x0+XR; x++)
                {
                  int color0 = mt.at<unsigned char>(y,x);// このｘ、ｙがエリア外参照？
                  if (color0 > CheckBW) //黒カウント 実際は反転なので白をカウント ２００
                    black[j][k]++;
                }
          }
  //////////////////////////////////////// ここまでは通常　////////////

  ////////////// 以下　一様に影がある場合　真ん中をリファレンスにする試行  この部分６✕6では不要？？？　2023-3-1////
      int ref = black[2][2];
  //  if((ref > 85)&&(ref < 190)){//70だとオリジナルでとれるものもエラーになる場合あり
    if((ref > 85)&&(ref < 700)){ //上記は250の場合で190を400に変更した　点字鋲の対策　300の場合の試行
      //100前後は突起内の影　西日などによる突起をはみ出した突起の本体の影は180を超えるケースあり
        for (int i=0;i<5;i++){
                //printf(" \n");
                  for(int j=0;j<5;j++){
                    black[i][j]=black[i][j]-ref;
                    if (black[i][j]<0) black[i][j]=0;
                    //printf(" %3d ",black[i][j]);//// -ref 2019-12-26
                  }
            }
      }
      ///////////////////////////////////
}
///////////////////// 5✕5通常ブロック
static void Black_point0(const Mat& mt, int black[5][5])
{
    int x,y,x0,y0;
    //////////////////// 周囲の枠を塗りつぶし/////// これは効果的　////////////////////
    // Red，太さ3，4近傍連結
    //rectangle(mt, cv::Point(0,0), cv::Point(300, 300), Scalar(0,0,0), 5, 4);
    //imshow("Rectangle",mt);
    rectangle(mt, cv::Point(0,0), cv::Point(300, 300), Scalar(0,0,0), 12, 12);
    //imshow("Rectangle - new ",mt);

    for(  int j = 0; j < 5; j++ )
        for( int k = 0; k < 5; k++)
          {

            x0 = 60*k;
            y0 = 60*j;
            ///////////////////////
            ////////////////////
            black[j][k]=0;
          /////////////////////////////////////////////////////////////////

            for (y=y0; y<y0+60; y++)
              for (x=x0; x<x0+60; x++)
                {
                  int color0 = mt.at<unsigned char>(y,x);// このｘ、ｙがエリア外参照？
                  if (color0 > CheckBW) //黒カウント 実際は反転なので白をカウント ２００
                    black[j][k]++;
                }
          }
  //////////////////////////////////////// ここまでは通常　////////////

  ////////////// 以下　一様に影がある場合　真ん中をリファレンスにする試行
      int ref = black[2][2];
    // if((ref > 85)&&(ref < 190)){//70だとオリジナルでとれるものもエラーになる場合あり
    //if((ref > 35)&&(ref < 190)){// 金属点字ブロックに対してのトライアル　2023-3-1 ref はすべて差し引いてもいいかも？？？
      //100前後は突起内の影　西日などによる突起をはみ出した突起の本体の影は180を超えるケースあり
    if((ref > 85)&&(ref < 700)){
        for (int i=0;i<5;i++){
                //printf(" \n");
                  for(int j=0;j<5;j++){
                    black[i][j]=black[i][j]-ref;
                    if (black[i][j]<0) black[i][j]=0;
                    //printf(" %3d ",black[i][j]);//// -ref 2019-12-26
                  }
            }
      }
      ///////////////////////////////////
}
@end
