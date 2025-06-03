import { useQuery } from "@tanstack/react-query"
import { useState } from "react"

export const InferenceCard = () => {

    const [prompt, setPrompt] = useState("")

    const requestTexture = () => {
        console.log("prompt " + prompt)
    }

    const { isPending, error, data, isFetching } = useQuery({
        queryKey: ['repoData'],
        queryFn: async () => {
            const response = await fetch('http://localhost:7070/inference', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                // your POST payload here
                prompt: 'yourData',
            }),
            mode: "cors",
        });

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            return response.json();
        },
    });


    if (isPending) return 'Loading...'

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
