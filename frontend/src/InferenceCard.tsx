import { useQuery } from "@tanstack/react-query"
import { useState } from "react"

type StatusResponse = {
    id: string;
    status: string;
    upload_path: string;
};

export const InferenceCard = () => {

    const [prompt, setPrompt] = useState("")
    // const [textureURL, setTextureURL] = useState<null | string>()

    const { error, data : start_task_data, refetch } = useQuery<StatusResponse>({
        queryKey: ['repoData'],
        queryFn: async () => {
            const response = await fetch('http://localhost:80/inference', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    prompt: prompt,
                }),
                mode: "cors",
            });
            
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            
            return response.json();
        },
        refetchOnWindowFocus: false,
        enabled: false
    });


    const {
        data: statusData,
        // error: error2,
        // isLoading: isLoading2,
        // isFetching: isFetching2,
    } = useQuery<StatusResponse>({
        queryKey: ['statusCheck', start_task_data?.id], // include job ID in key
        queryFn: async () => {

            if (start_task_data != undefined || start_task_data != null) {
                const response = await fetch(`http://localhost:80/status/${start_task_data.id}`, {
                    method: 'GET',
                    mode: 'cors',
                });
    
                if (!response.ok) {
                    throw new Error('Network response was not ok');
                }
    
                return response.json();

            }
            else{
                const res : StatusResponse = {
                    "status" : "something wrong",
                    id: "-1",
                    upload_path: ""
                }
                return res
            }
        },
        enabled: !!start_task_data,
        refetchInterval: (query) => {
            return query.state.data?.status === 'finished' ? false : 5000;
        },
        refetchOnWindowFocus: false,
    });

    
    const requestTexture = () => {
        console.log("prompt " + prompt)
        refetch();
        // console.log("res " + res)
        // setTextureURL(res)
    }
    
    // if (isPending) return 'Loading...'
    
    if (error) return 'An error has occurred: ' + error.message

    return(
        <>
            {/* <p>{JSON.stringify(start_task_data)}</p> */}
            <p>{JSON.stringify(statusData)}</p>
            {
                (statusData && statusData.upload_path !== "") ? <img src={statusData.upload_path} /> : null
            }
            <input onChange={e => setPrompt(e.target.value)} />
            <button onClick={() => requestTexture()}>
                Generate Texture
            </button>
        </>
    )
}