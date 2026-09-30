'use strict';
function adtsRecordingStructure(b,{maxFrames=253126,maxDuration=5400000}={}){
 const rates=[96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350];
 const fail=()=>{throw Error('MEDIA_INVALID_OR_UNSUPPORTED');};
 let p=0,rate,channels,index;const frames=[];
 while(p<b.length){
  if(p+7>b.length||b[p]!==255||(b[p+1]&254)!==240||(b[p+1]&1)!==1||(b[p+2]>>6)!==1||(b[p+6]&3)!==0)fail();
  const fi=(b[p+2]>>2)&15,ch=((b[p+2]&1)<<2)|(b[p+3]>>6),length=((b[p+3]&3)<<11)|(b[p+4]<<3)|(b[p+5]>>5);
  if(!rates[fi]||rates[fi]<8000||rates[fi]>48000||![1,2].includes(ch)||length<=7||p+length>b.length||frames.length>=maxFrames)fail();
  if(rate&&(rate!==rates[fi]||channels!==ch))fail();
  rate=rates[fi];channels=ch;index=fi;frames.push([p+7,length-7]);p+=length;
 }
 if(!frames.length)fail();const upperMs=Math.ceil(frames.length*1024/rate*1000);if(upperMs>maxDuration)fail();
 return {kind:'aac',asc:Buffer.from([(2<<3)|(index>>1),((index&1)<<7)|(channels<<3)]),frames,rate,channels,upperMs};
}
module.exports={adtsRecordingStructure};
