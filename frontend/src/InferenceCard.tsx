import { useQuery } from "@tanstack/react-query"
import { useState } from "react"

export const InferenceCard = () => {

    const [prompt, setPrompt] = useState("")

    const { isPending, error, data, isFetching, refetch } = useQuery({
        queryKey: ['repoData'],
        queryFn: async () => {
            const response = await fetch('http://localhost:7070/inference', {
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
    
    const requestTexture = () => {
        console.log("prompt " + prompt)
        refetch();
    }
    
    // if (isPending) return 'Loading...'
    
    if (error) return 'An error has occurred: ' + error.message

    return(
        <>
            <input onChange={e => setPrompt(e.target.value)} />
            <button onClick={() => requestTexture()}>
                Generate Texture
            </button>
        </>
    )
}
